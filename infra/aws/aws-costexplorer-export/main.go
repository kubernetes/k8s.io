/*
Copyright 2022 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// aws-costexplorer-export
// exports data from AWS Cost Explorer and imports it into a GCS Bucket as CSV

package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"github.com/jszwec/csvutil"
	"log"
	"os"
	"path"
	"strings"
	"time"

	"cloud.google.com/go/bigquery"
	"github.com/aws/aws-sdk-go-v2/aws"
	awssdkconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/costexplorer"
	cetypes "github.com/aws/aws-sdk-go-v2/service/costexplorer/types"
	"gocloud.dev/blob"
	_ "gocloud.dev/blob/fileblob"
	_ "gocloud.dev/blob/gcsblob"
	_ "gocloud.dev/blob/memblob"
	_ "gocloud.dev/blob/s3blob"
	"google.golang.org/api/iterator"
)

// Table types the main keys from the costAndUsageOutput and the BigQuery tables
type Table struct {
	Name   string
	Schema interface{}
}

// recreation of the CostExplorer types is required
type ResultByTime struct {
	Estimated       bool
	TimePeriodStart string
	TimePeriodEnd   string
	Keys            string
	Unit            string
	Amount          string
}

type ResultByTimeSchema struct {
	Estimated       bigquery.NullBool    `bigquery:"Estimated"`
	TimePeriodStart bigquery.NullString  `bigquery:"TimePeriodStart"`
	TimePeriodEnd   bigquery.NullString  `bigquery:"TimePeriodEnd"`
	Keys            bigquery.NullString  `bigquery:"Keys"`
	Unit            bigquery.NullString  `bigquery:"Unit"`
	Amount          bigquery.NullFloat64 `bigquery:"Amount"`
}

type DimensionValuesWithAttributes struct {
	Description string
	Value       string
}

type DimensionValuesWithAttributesSchema struct {
	Description bigquery.NullString `bigquery:"Description"`
	Value       bigquery.NullString `bigquery:"Value"`
}

// FileOutputs maps a file name to content
type FileOutputs map[string]string

// AWSCostExplorerExportConfig stores configuration for the runtime
type AWSCostExplorerExportConfig struct {
	AWSRegion                     string
	LocalOutputFolder             string
	LocalOutputFolderEnable       bool
	BucketURI                     string
	AmountOfDaysToReportFrom      int
	PromoteToLatest               bool
	GCPProjectID                  string
	BigQueryEnabled               bool
	BigQueryDatasetLocation       string
	BigQueryManagingDatasetPrefix string

	// clients
	ceclient *costexplorer.Client
	bqclient *bigquery.Client
}

// consts
const (
	// formats
	usageDateFormat  = "2006-01-02"
	resultDateFormat = "200601021504"

	// templates
	fileNameTemplate            = "cncf-aws-infra-billing-and-usage-data-%v-%v.csv"
	bigqueryDatasetNameTemplate = "%v_%v"
	bucketReferenceTemplate     = "%v/%v"
)

// default config for runtime
var (
	defaultConfig = AWSCostExplorerExportConfig{
		AWSRegion:                     "us-east-1",
		LocalOutputFolder:             "/tmp/local-cncf-aws-infra-billing-and-usage-data",
		LocalOutputFolderEnable:       false,
		BucketURI:                     "gs://cncf-aws-infra-cost-and-billing-data",
		AmountOfDaysToReportFrom:      365,
		PromoteToLatest:               true,
		GCPProjectID:                  "k8s-infra-ii-sandbox",
		BigQueryEnabled:               true,
		BigQueryDatasetLocation:       "australia-southeast1",
		BigQueryManagingDatasetPrefix: "cncf_aws_infra_cost_and_billing_data_dataset",
	}

	tableResultsByTime            Table = Table{Name: "ResultsByTime", Schema: ResultByTimeSchema{}}
	tableDimensionValueAttributes Table = Table{Name: "DimensionValueAttributes", Schema: DimensionValuesWithAttributes{}}

	tables = []Table{
		tableResultsByTime,
		tableDimensionValueAttributes,
	}
	now = time.Now()
)

func marshalAsJSON(input interface{}) string {
	o, err := json.Marshal(input)
	if err != nil {
		log.Println("error marshalling JSON", err)
		return ""
	}
	return string(o)
}

func marshalAsCSV(input interface{}) string {
	o, err := csvutil.Marshal(input)
	if err != nil {
		fmt.Println("error marshalling CSV:", err)
		return ""
	}
	return string(o)
}

func writeFile(path string, contents string) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(contents)
	if err != nil {
		return err
	}
	return nil
}

func stringForStringPointer(input *string) string {
	if input == nil {
		return ""
	}
	return *input
}

// usageClient stores the client for costexplorer
type usageClient struct {
	client *costexplorer.Client
	config AWSCostExplorerExportConfig
}

// GetInputForUsage returns an input for making the cost and usage data request
func (c usageClient) GetInputForUsage(nextPageToken *string) *costexplorer.GetCostAndUsageInput {
	start := now.
		Add(-time.Duration(time.Hour * 24 * time.Duration(c.config.AmountOfDaysToReportFrom))).
		Format(usageDateFormat)
	end := now.Format(usageDateFormat)
	input := &costexplorer.GetCostAndUsageInput{
		Filter: &cetypes.Expression{
			Not: &cetypes.Expression{
				Dimensions: &cetypes.DimensionValues{
					Key:          cetypes.DimensionPurchaseType,
					MatchOptions: []cetypes.MatchOption{cetypes.MatchOptionEquals},
					Values:       []string{"Refund", "Credit"},
				},
			},
		},
		Metrics:     []string{string(cetypes.MetricUnblendedCost)},
		Granularity: cetypes.GranularityDaily,
		GroupBy: []cetypes.GroupDefinition{{
			Type: cetypes.GroupDefinitionTypeDimension,
			Key:  aws.String(string(cetypes.DimensionLinkedAccount)),
		}},
		TimePeriod: &cetypes.DateInterval{
			Start: aws.String(start),
			End:   aws.String(end),
		},
		NextPageToken: nextPageToken,
	}
	return input
}

// GetUsage returns the cost and usage data collected without pages
func (c usageClient) GetUsage() (costAndUsageOutput *costexplorer.GetCostAndUsageOutput, err error) {
	costAndUsageOutput = &costexplorer.GetCostAndUsageOutput{}
	var nextPageToken *string
	for page := 0; true; page++ {
		input := c.GetInputForUsage(nextPageToken)
		usage, err := c.client.GetCostAndUsage(context.TODO(), input)
		if err != nil {
			return &costexplorer.GetCostAndUsageOutput{}, fmt.Errorf("error with getting usage, %v", err)
		}
		if usage == nil {
			break
		}
		log.Printf("- page (%v): dimensions (%v); group definitions (%v); results by time (%v)\n", page, len(usage.DimensionValueAttributes), len(usage.GroupDefinitions), len(usage.ResultsByTime))
		costAndUsageOutput.DimensionValueAttributes = append(costAndUsageOutput.DimensionValueAttributes, usage.DimensionValueAttributes...)
		costAndUsageOutput.ResultsByTime = append(costAndUsageOutput.ResultsByTime, usage.ResultsByTime...)

		if usage.NextPageToken == nil {
			break
		}
		nextPageToken = usage.NextPageToken
		costAndUsageOutput.ResultMetadata = usage.ResultMetadata
	}
	costAndUsageOutput.NextPageToken = nil
	if len(costAndUsageOutput.ResultsByTime) == 0 {
		return &costexplorer.GetCostAndUsageOutput{}, fmt.Errorf("error: empty dataset")
	}
	return costAndUsageOutput, nil
}

// BucketAccess stores config for accessing a bucket
type BucketAccess struct {
	URI    string
	Bucket *blob.Bucket
}

// Open returns access to a bucket
func (b BucketAccess) Open() (BucketAccess, error) {
	bucket, err := blob.OpenBucket(context.TODO(), b.URI)
	if err != nil {
		return BucketAccess{}, err
	}
	b.Bucket = bucket
	return b, nil
}

// WriteToFile writes a file in the bucket with access
func (b BucketAccess) WriteToFile(name string, data string) (err error) {
	w, err := b.Bucket.NewWriter(context.TODO(), name, nil)
	if err != nil {
		return err
	}
	_, writeErr := fmt.Fprintln(w, data)
	closeErr := w.Close()
	if writeErr != nil {
		return err
	}
	if closeErr != nil {
		return err
	}
	return nil
}

func (c AWSCostExplorerExportConfig) NewGCSRefForConfig(tableName string) *bigquery.GCSReference {
	gcsRef := bigquery.NewGCSReference(
		fmt.Sprintf(bucketReferenceTemplate,
			c.BucketURI,
			fmt.Sprintf(fileNameTemplate, tableName, "latest")))
	gcsRef.SourceFormat = bigquery.CSV
	return gcsRef
}

func (c AWSCostExplorerExportConfig) CheckIfBigQueryDatasetExists(suffix string) (err error) {
	name := fmt.Sprintf(bigqueryDatasetNameTemplate, c.BigQueryManagingDatasetPrefix, suffix)
	md, err := c.bqclient.Dataset(name).Metadata(context.TODO())
	if err != nil {
		return err
	}
	if name != md.Name {
		return fmt.Errorf("Dataset not found, names don't match '%v' != '%v'", name, md.Name)
	}
	return nil
}

func (c AWSCostExplorerExportConfig) CreateBigQueryDataset(suffix string) (err error) {
	name := fmt.Sprintf(bigqueryDatasetNameTemplate, c.BigQueryManagingDatasetPrefix, suffix)
	err = c.bqclient.Dataset(name).Create(context.TODO(), &bigquery.DatasetMetadata{
		Location: c.BigQueryDatasetLocation,
	})
	if err != nil {
		return err
	}
	return nil
}

func (c AWSCostExplorerExportConfig) DeleteBigQueryDataset(suffix string) (err error) {
	name := fmt.Sprintf(bigqueryDatasetNameTemplate, c.BigQueryManagingDatasetPrefix, suffix)
	tables := c.bqclient.Dataset(name).Tables(context.TODO())
	for {
		t, err := tables.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Printf("error with listing tables, %v\n", err)
			break
		}
		log.Printf("Deleting table '%v' in dataset '%v'", t.TableID, name)
		err = t.Delete(context.TODO())
		if err != nil {
			log.Printf("error with listing tables, %v\n", err)
			break
		}
	}
	err = c.bqclient.Dataset(name).Delete(context.TODO())
	if err != nil {
		return err
	}
	return nil
}

func (c AWSCostExplorerExportConfig) NewSchemaForInterface(obj interface{}) (schema bigquery.Schema, err error) {
	schema, err = bigquery.InferSchema(obj)
	if err != nil {
		return bigquery.Schema{}, fmt.Errorf("error inferring schema: %v", err)
	}
	return schema, nil
}

func (c AWSCostExplorerExportConfig) LoadBigQueryDatasetFromGCS(suffix string, table Table) (err error) {
	datasetName := fmt.Sprintf(bigqueryDatasetNameTemplate, c.BigQueryManagingDatasetPrefix, suffix)
	gcsRef := c.NewGCSRefForConfig(string(tableResultsByTime.Name))
	schema, err := c.NewSchemaForInterface(table.Schema)
	if err != nil {
		return err
	}
	gcsRef.SkipLeadingRows = 1
	gcsRef.AllowJaggedRows = true
	gcsRef.AllowQuotedNewlines = true
	gcsRef.Schema = schema
	loader := c.bqclient.Dataset(datasetName).Table(string(tableResultsByTime.Name)).LoaderFrom(gcsRef)
	loader.WriteDisposition = bigquery.WriteEmpty

	job, err := loader.Run(context.TODO())
	if err != nil {
		return err
	}
	status, err := job.Wait(context.TODO())
	if err != nil {
		return err
	}
	if status.Err() != nil {
		errors := func() (errs string) {
			for _, err := range status.Errors {
				errs += fmt.Sprintf("\n - %v %v %v", err.Location, err.Message, err.Reason)
			}
			return errs
		}()
		return fmt.Errorf("job completed with error: %v\n\nerrors: %#v\n", status.Err(), errors)
	}
	return nil
}

func FormatCostAndUsageOutputAsFileOutputs(costAndUsageOutput *costexplorer.GetCostAndUsageOutput) (fileOutputs FileOutputs) {
	fileOutputs = FileOutputs{}
	resultsByTime := []ResultByTime{}
	for _, value := range costAndUsageOutput.ResultsByTime {
		for _, g := range value.Groups {
			resultsByTime = append(resultsByTime, ResultByTime{
				Estimated:       value.Estimated,
				Keys:            strings.Join(g.Keys, " "),
				Amount:          stringForStringPointer(g.Metrics["UnblendedCost"].Amount),
				Unit:            stringForStringPointer(g.Metrics["UnblendedCost"].Unit),
				TimePeriodStart: stringForStringPointer(value.TimePeriod.Start),
				TimePeriodEnd:   stringForStringPointer(value.TimePeriod.End),
			})
		}
	}
	o := marshalAsCSV(resultsByTime)
	fileOutputs[string(tableResultsByTime.Name)] = o

	dimensionValueAttributes := []DimensionValuesWithAttributes{}
	for _, value := range costAndUsageOutput.DimensionValueAttributes {
		log.Printf("dimensionValuAttributes: %#v\n", value)
		dimensionValueAttributes = append(dimensionValueAttributes, DimensionValuesWithAttributes{
			Value:       *value.Value,
			Description: value.Attributes["description"],
		})
	}
	o = marshalAsCSV(dimensionValueAttributes)
	fileOutputs[string(tableDimensionValueAttributes.Name)] = o

	return fileOutputs
}

func main() {
	var config AWSCostExplorerExportConfig
	flag.StringVar(&config.AWSRegion, "aws-region", defaultConfig.AWSRegion, "specify an AWS region")
	flag.StringVar(&config.LocalOutputFolder, "output-file", defaultConfig.LocalOutputFolder, "specify a local file to write the usage CSV data to")
	flag.BoolVar(&config.LocalOutputFolderEnable, "output-file-enable", defaultConfig.LocalOutputFolderEnable, "specify whether the usage data is also written to disk locally")
	flag.StringVar(&config.BucketURI, "bucket-uri", defaultConfig.BucketURI, "specify a bucket to write to")
	flag.IntVar(&config.AmountOfDaysToReportFrom, "days-ago", defaultConfig.AmountOfDaysToReportFrom, "specify the amount of days back to report from today")
	flag.BoolVar(&config.PromoteToLatest, "promote-to-latest", defaultConfig.PromoteToLatest, "specifies whether to promote the cost and usage data to latest CSV files")
	flag.BoolVar(&config.BigQueryEnabled, "bigquery-enabled", defaultConfig.BigQueryEnabled, "specifies whether to load data into BigQuery from the specified bucket")
	flag.StringVar(&config.GCPProjectID, "gcp-project-id", defaultConfig.GCPProjectID, "specifies the GCP project to use")
	flag.StringVar(&config.BigQueryDatasetLocation, "bigquery-dataset-location", defaultConfig.BigQueryDatasetLocation, "specifies BigQuery dataset location")
	flag.StringVar(&config.BigQueryManagingDatasetPrefix, "bigquery-managing-dataset-prefix", defaultConfig.BigQueryManagingDatasetPrefix, "specifies a prefix to use for managing BigQuery datasets")
	flag.Parse()

	log.Println("Run time:", now)
	log.Printf("Config: %#v\n", config)
	log.Println("Will start in 5s")
	time.Sleep(time.Second * 5)

	cfg, err := awssdkconfig.LoadDefaultConfig(context.TODO(),
		awssdkconfig.WithRegion(config.AWSRegion),
	)
	if err != nil {
		log.Printf("unable to load SDK config, %v", err)
		return
	}

	ceclient := costexplorer.NewFromConfig(cfg)

	log.Println("Fetching usage data")
	uc := usageClient{client: ceclient, config: config}
	costAndUsageOutput, err := uc.GetUsage()
	if err != nil {
		log.Printf("%v", err)
		return
	}
	log.Println("Fetched usage data")

	log.Println("Formatting data")
	fileOutputs := FormatCostAndUsageOutputAsFileOutputs(costAndUsageOutput)
	log.Println("Formatted data")

	if config.LocalOutputFolderEnable {
		_ = os.Mkdir(config.LocalOutputFolder, 0700)
		log.Printf("Writing usage data to files in '%v'\n", config.LocalOutputFolder)
		for name, content := range fileOutputs {
			log.Printf("- writing '%v'\n", name)
			err = writeFile(path.Join(config.LocalOutputFolder, name+".csv"), content)
			if err != nil {
				log.Printf("%v", err)
				return
			}
		}
		log.Printf("Wrote usage data to file '%v'\n", config.LocalOutputFolder)
	}
	log.Printf("Opening GCS bucket '%v'\n", config.BucketURI)
	ba := BucketAccess{URI: config.BucketURI}
	ba, err = ba.Open()
	if err != nil {
		log.Printf("%v", err)
		return
	}
	defer func() {
		log.Printf("Closing GCS bucket '%v'\n", config.BucketURI)
		ba.Bucket.Close()
	}()
	for name, content := range fileOutputs {
		fileNames := []string{
			fmt.Sprintf(fileNameTemplate, name, now.Format(resultDateFormat)),
		}
		if config.PromoteToLatest {
			fileNames = append(fileNames, fmt.Sprintf(fileNameTemplate, name, "latest"))
		}
		for _, fileName := range fileNames {
			log.Printf("Uploading '%v' to '%v/%v'", fileName, config.BucketURI, fileName)
			err = ba.WriteToFile(fileName, content)
			if err != nil {
				log.Printf("%v", err)
				return
			}
			log.Printf("Uploaded '%v' to '%v/%v' successfully", fileName, config.BucketURI, fileName)
		}
	}

	if !(config.BigQueryEnabled && strings.HasPrefix(config.BucketURI, "gs://")) {
		log.Println("BigQuery loading disabled or not using prefix; Complete.")
		return
	}

	// bigquery stuff
	//   1. create dataset based on date
	//   1.1 create tables 1-3 using bigquery.InferSchema
	//   2. load into dataset based on date
	//   3. if not promoting, exit
	//   4. delete latest dataset
	//   5. create latest dataset
	//   5.1 create tables 1-3 using bigquery.InferSchema
	//   6. load into latest dataset
	ctx := context.Background()
	client, err := bigquery.NewClient(ctx, config.GCPProjectID)
	if err != nil {
		log.Println("error bigquery.NewClient: %v", err)
		return
	}
	defer client.Close()
	config.bqclient = client

	sets := []string{
		now.Format(resultDateFormat),
	}
	if config.PromoteToLatest {
		sets = append(sets, "latest")
	}

	for _, set := range sets {
		name := fmt.Sprintf(bigqueryDatasetNameTemplate, config.BigQueryManagingDatasetPrefix, set)
		if err := config.DeleteBigQueryDataset(set); err != nil {
			log.Printf("error deleting dataset '%v', %v\n", set, err)
		} else {
			log.Printf("Deleted existing dataset '%v'\n", set)
		}
		log.Printf("Creating dataset '%v'\n", name)
		if err := config.CreateBigQueryDataset(set); err != nil {
			log.Printf("error creating new dataset '%v', %v\n", name, err)
		}
		log.Printf("Created dataset '%v'\n", name)
		for _, table := range tables {
			log.Printf("Loading table '%v' into dataset '%v'\n", table.Name, name)
			err := config.LoadBigQueryDatasetFromGCS(set, table)
			if err != nil {
				log.Printf("error loading dataset table '%v.%v', %v\n", name, table.Name, err)
			}
			log.Printf("- Loaded tables '%v' successfully\n", table.Name)
		}
	}
}
