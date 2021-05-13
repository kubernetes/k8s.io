package main

import (
	"context"
	"encoding/csv"
	"flag"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	bigquery "cloud.google.com/go/bigquery/storage/apiv1beta2"
	"cloud.google.com/go/storage"
	"github.com/golang/protobuf/proto"
	"google.golang.org/api/iterator"
	bigquerypb "google.golang.org/genproto/googleapis/cloud/bigquery/storage/v1beta2"
	"google.golang.org/protobuf/reflect/protodesc"
	"k8s.io/klog/v2"

	"k8s.io/k8s.io/metrics/access-logs/loader/pkg/datapb"
	"k8s.io/k8s.io/metrics/access-logs/loader/pkg/ipinfo"
)

func main() {
	err := run(context.Background())
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}

type Loader struct {
	Bucket string

	ipStore *ipinfo.Store

	gcs *storage.Client
	bq  *bigquery.BigQueryWriteClient

	project string
	dataset string
	table   string

	metadataKey     string
	metadataVersion string
}

func run(ctx context.Context) error {
	project := ""
	flag.StringVar(&project, "project", project, "GCP project to upload to")

	klog.InitFlags(nil)

	flag.Parse()

	if project == "" {
		return fmt.Errorf("--project is required")
	}

	store := &ipinfo.Store{}
	if err := store.Refresh(); err != nil {
		return nil
	}

	store.Dump(os.Stdout)

	for {
		l := Loader{
			Bucket: "k8s-artifacts-gcslogs",

			project: project,
			dataset: "kubernetes_public_logs",
			table:   "raw_gcs_logs",

			metadataKey:     "k8s-io-loaded-bq",
			metadataVersion: "v2",
		}

		// TODO: Refresh the IP map periodically?
		l.ipStore = store

		err := l.Run(ctx)
		if err != nil {
			return err
		}
		klog.Infof("done")
		time.Sleep(5 * time.Minute)
	}
}

func (l *Loader) Run(ctx context.Context) error {
	var errors []error

	gcs, err := storage.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("storage.NewClient failed: %w", err)
	}

	l.gcs = gcs

	bq, err := bigquery.NewBigQueryWriteClient(ctx)
	if err != nil {
		return fmt.Errorf("NewBigQueryWriteClient failed: %w", err)
	}
	defer bq.Close()
	l.bq = bq

	klog.Infof("scanning for objects")
	it := l.gcs.Bucket(l.Bucket).Objects(ctx, nil)
	for {
		attrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return fmt.Errorf("Bucket(%q).Objects failed: %w", "gs://"+l.Bucket, err)
		}
		// TODO: accumulate errors?
		if err := l.loadObject(ctx, attrs); err != nil {
			e := fmt.Errorf("loadObject(%q) failed: %w", "gs://"+l.Bucket+"/"+attrs.Name, err)
			errors = append(errors, e)
			klog.Warningf("continuing after error: %v", e)
		}
	}
	if len(errors) == 0 {
		return nil
	}
	return errors[0]
}

func (l *Loader) loadObject(ctx context.Context, attrs *storage.ObjectAttrs) error {
	if attrs.Metadata[l.metadataKey] == l.metadataVersion {
		// Already loaded
		return nil
	}

	if strings.Contains(attrs.Name, "_storage_") {
		// A storage record
		// TODO: It would be better if we checked the contents of the file, but by the time we've done that below, we've already opened a stream etc.
		return nil
	}

	gsPath := "gs://" + l.Bucket + "/" + attrs.Name
	klog.Infof("loading %s", gsPath)
	r, err := l.gcs.Bucket(l.Bucket).Object(attrs.Name).NewReader(ctx)
	if err != nil {
		return fmt.Errorf("Object(%q).NewReader failed: %w", gsPath, err)
	}
	defer r.Close()

	// Create a stream in PENDING mode, so a flush writes the whole batch or nothing
	stream, err := l.bq.CreateWriteStream(ctx, &bigquerypb.CreateWriteStreamRequest{
		Parent: "projects/" + l.project + "/datasets/" + l.dataset + "/tables/" + l.table,
		WriteStream: &bigquerypb.WriteStream{
			Type: bigquerypb.WriteStream_PENDING,
		},
	})
	if err != nil {
		return fmt.Errorf("CreateWriteStream() failed: %w", err)
	}

	rowWriter, err := l.bq.AppendRows(ctx)
	if err != nil {
		return fmt.Errorf("AppendRows() failed: %w", err)
	}

	descriptor := (&datapb.RawGCSRow{}).ProtoReflect().Descriptor()

	protoDesc := protodesc.ToDescriptorProto(descriptor)
	// TODO: Shouldn't this be automatic?
	for _, field := range protoDesc.Field {
		if field.GetTypeName() == ".datapb.RawGCSRow.CIDRInfo" {
			typeName := "CIDRInfo"
			field.TypeName = &typeName
		}
	}

	// protoDesc.NestedType = append(protoDesc.NestedType, protodesc.ToDescriptorProto((&datapb.RawGCSRow_CIDRInfo{}).ProtoReflect().Descriptor()))
	writerSchema := &bigquerypb.ProtoSchema{
		ProtoDescriptor: protoDesc,
	}

	var rowBuffers [][]byte
	flushSize := 1000

	flush := func() error {
		if len(rowBuffers) == 0 {
			return nil
		}

		appendRowsRequest := &bigquerypb.AppendRowsRequest{
			WriteStream: stream.Name,
			// TODO: Offset,
			Rows: &bigquerypb.AppendRowsRequest_ProtoRows{
				ProtoRows: &bigquerypb.AppendRowsRequest_ProtoData{
					WriterSchema: writerSchema,
					Rows: &bigquerypb.ProtoRows{
						SerializedRows: rowBuffers,
					},
				},
			},
		}
		if err := rowWriter.Send(appendRowsRequest); err != nil {
			return fmt.Errorf("Send to row stream failed: %w", err)
		}
		appendRowsResponse, err := rowWriter.Recv()
		if err != nil {
			return fmt.Errorf("Recv from row stream failed: %w", err)
		}

		// TODO: Can we / should we check something here?
		klog.Infof("result %+v", appendRowsResponse)
		// if appendRowsResponse.Response.(*bigquerypb.AppendRowsResponse_AppendResult_).AppendResult != OK {
		// 	return fmt.Errorf("unexpected status from row stream: %v", appendRowsResponse)
		// }
		rowBuffers = nil

		return nil
	}

	csvReader := csv.NewReader(r)
	n := 0
	for {
		record, err := csvReader.Read()
		if err != nil {
			if err == io.EOF {
				break
			}
			return fmt.Errorf("csv.Read() failed: %w", err)
		}

		n++

		// klog.Infof("record: %v", record)

		if n == 1 && record[0] == "time_micros" {
			// Skip header row
			continue
		}

		if len(record) != 17 {
			return fmt.Errorf("unexpected length record %d: %v", len(record), record)
		}

		var parseErr error
		parseInt32 := func(s string) int32 {
			if s == "" {
				return 0
			}
			v, err := strconv.ParseInt(s, 10, 32)
			if err != nil {
				parseErr = err
			}
			return int32(v)
		}
		parseInt64 := func(s string) int64 {
			if s == "" {
				return 0
			}
			v, err := strconv.ParseInt(s, 10, 64)
			if err != nil {
				parseErr = err
			}
			return v
		}

		row := &datapb.RawGCSRow{
			RequestTime:     parseInt64(record[0]),
			CIp:             record[1],
			CIpType:         parseInt32(record[2]),
			CIpRegion:       record[3],
			CsMethod:        record[4],
			CsUri:           record[5],
			ScStatus:        parseInt32(record[6]),
			CsBytes:         parseInt64(record[7]),
			ScBytes:         parseInt64(record[8]),
			TimeTakenMicros: parseInt64(record[9]),
			CsHost:          record[10],
			CsReferer:       record[11],
			CsUserAgent:     record[12],
			SRequestId:      record[13],
			CsOperation:     record[14],
			CsBucket:        record[15],
			CsObject:        record[16],
		}

		if parseErr != nil {
			return fmt.Errorf("failed to parse row %v: %w", record, parseErr)
		}

		sanitizeUTF8(&row.CsObject)

		if row.CIp != "" {
			info := l.ipStore.Lookup(row.CIp)
			if info != nil {
				row.CidrInfo = &datapb.RawGCSRow_CIDRInfo{
					Entity:                info.Entity,
					Service:               info.Service,
					Region:                info.Region,
					AwsNetworkBorderGroup: info.AwsNetworkBorderGroup,
				}
			}
		}

		rowBuffer, err := proto.Marshal(row)
		if err != nil {
			//klog.Infof("row: %+v", row)
			return fmt.Errorf("proto.Marshal failed: %w", err)
		}
		rowBuffers = append(rowBuffers, rowBuffer)
		if len(rowBuffers) >= flushSize {
			flush()
		}
	}

	if err := flush(); err != nil {
		return err
	}

	if err := rowWriter.CloseSend(); err != nil {
		return fmt.Errorf("CloseSend failed: %w", err)
	}

	klog.Infof("starting finalize")
	finalizeResponse, err := l.bq.FinalizeWriteStream(ctx, &bigquerypb.FinalizeWriteStreamRequest{
		Name: stream.Name,
	})
	if err != nil {
		return fmt.Errorf("FinalizeWriteStream() failed: %w", err)
	}

	klog.Infof("finalized %d rows", finalizeResponse.RowCount)

	commitResponse, err := l.bq.BatchCommitWriteStreams(ctx, &bigquerypb.BatchCommitWriteStreamsRequest{
		Parent:       "projects/" + l.project + "/datasets/" + l.dataset + "/tables/" + l.table,
		WriteStreams: []string{stream.Name},
	})
	if err != nil {
		return fmt.Errorf("BatchCommitWriteStreams() failed: %w", err)
	}

	for _, streamError := range commitResponse.StreamErrors {
		return fmt.Errorf("BatchCommitWriteStreams failed: %v", streamError)
	}

	obj := l.gcs.Bucket(l.Bucket).Object(attrs.Name)
	if _, err := obj.Update(ctx, storage.ObjectAttrsToUpdate{
		Metadata: map[string]string{
			l.metadataKey: l.metadataVersion,
		},
	}); err != nil {
		return fmt.Errorf("failed to update object attributes on %q: %w", gsPath, err)
	}

	return nil
}

// Some rows have invalid utf8 strings, which can't be encoded in proto and send to BigQuery.
// We replace the invalid characters with '?'
func sanitizeUTF8(s *string) {
	if utf8.ValidString(*s) {
		return
	}

	var sb strings.Builder
	for _, r := range *s {
		if !utf8.ValidRune(r) {
			sb.WriteRune('?')
		} else {
			sb.WriteRune(r)
		}
	}
	*s = sb.String()
}
