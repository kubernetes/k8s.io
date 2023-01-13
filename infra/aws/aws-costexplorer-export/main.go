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
	"crypto/sha256"
	"flag"
	"fmt"
	"io"
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
	"github.com/google/uuid"
	"github.com/jszwec/csvutil"
	"gocloud.dev/blob"
	_ "gocloud.dev/blob/fileblob"
	_ "gocloud.dev/blob/gcsblob"
	_ "gocloud.dev/blob/memblob"
	_ "gocloud.dev/blob/s3blob"
	"google.golang.org/api/iterator"
	"sigs.k8s.io/yaml"
)

// Table types the main keys from the costAndUsageOutput and the BigQuery tables
type Table struct {
	Name   string
	Schema interface{}
}

// ResultByTime is a recreation of the CostExplorer types is required
// it stores the amount for each day a bill was made
type ResultByTime struct {
	ID              string
	Estimated       bool
	TimePeriodStart string
	TimePeriodEnd   string
	Unit            string
	Amount          string
	ProjectID       string
	ProjectName     string
}

// ResultByTimeSchema is a struct that matches ResultByTime
// but is written for BigQuery schema loading
type ResultByTimeSchema struct {
	ID              bigquery.NullString  `bigquery:"ID"`
	Estimated       bigquery.NullBool    `bigquery:"Estimated"`
	TimePeriodStart bigquery.NullString  `bigquery:"TimePeriodStart"`
	TimePeriodEnd   bigquery.NullString  `bigquery:"TimePeriodEnd"`
	Unit            bigquery.NullString  `bigquery:"Unit"`
	Amount          bigquery.NullFloat64 `bigquery:"Amount"`
	ProjectID       bigquery.NullString  `bigquery:"ProjectID"`
	ProjectName     bigquery.NullString  `bigquery:"ProjectName"`
}

// FileOutputs maps a file name to content
type FileOutputs map[string]string

// AWSCostExplorerExportConfig stores configuration for the runtime
type AWSCostExplorerExportConfig struct {
	AWSRegion                     string
	AmountOfDaysToReportFrom      int
	BigQueryDatasetLocation       string
	BigQueryEnabled               bool
	BigQueryManagingDatasetPrefix string
	BucketURI                     string
	FilterByLinkedAccounts        []string
	GCPProjectID                  string
	LocalOutputFolder             string
	LocalOutputFolderEnable       bool
	PromoteToLatest               bool

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
	fileNamePrefix              = "k8s-infra-aws-infra-billing-and-usage-data"
	fileNameTemplate            = fileNamePrefix + "-%v-%v.csv"
	bigqueryDatasetNameTemplate = "%v_%v"
	bucketReferenceTemplate     = "%v/%v"
	setLatestName               = "latest"
)

// default config for runtime
var (
	defaultConfig = AWSCostExplorerExportConfig{
		AWSRegion: "us-east-1",
		FilterByLinkedAccounts: []string{
			"513428760722", // Root/Kubernetes/registry.k8s.io/registry.k8s.io_admin (k8s-infra-aws-registry-k8s-io-admin@kubernetes.io)
			"585803375430", // Root/Kubernetes/k8s-infra-accounts (k8s-infra-accounts@kubernetes.io)
			"266690972299", // Root/Kubernetes/k8s-infra-aws-root-account (k8s-infra-aws-root-account@kubernetes.io)
			"433650573627", // Root/Kubernetes/sig-release-leads (sig-release-leads@kubernetes.io)
		},
		LocalOutputFolder:             "/tmp/local-k8s-infra-aws-infra-billing-and-usage-data",
		LocalOutputFolderEnable:       false,
		BucketURI:                     "gs://k8s-infra-aws-infra-cost-and-billing-data",
		AmountOfDaysToReportFrom:      365,
		PromoteToLatest:               true,
		GCPProjectID:                  "k8s-infra-ii-sandbox",
		BigQueryEnabled:               true,
		BigQueryDatasetLocation:       "australia-southeast1",
		BigQueryManagingDatasetPrefix: "k8s_infra_aws_infra_cost_and_billing_data_dataset",
	}

	tableResultsByTime Table = Table{Name: "ResultsByTime", Schema: ResultByTimeSchema{}}

	tables = []Table{
		tableResultsByTime,
	}
	now = time.Now()
)

func marshalAsYAML(input interface{}) string {
	o, err := yaml.Marshal(input)
	if err != nil {
		log.Println("error marshalling YAML", err)
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

func generateUUIDFromInterface(i interface{}) string {
	yamlString := marshalAsYAML(i)
	sumBytes := sha256.Sum256([]byte(yamlString))
	sum := fmt.Sprintf("%x", sumBytes)
	sum = sum[:32]
	id, _ := uuid.Parse(sum)
	return id.String()
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
			And: []cetypes.Expression{
				{
					Dimensions: &cetypes.DimensionValues{
						Key:          cetypes.DimensionLinkedAccount,
						MatchOptions: []cetypes.MatchOption{cetypes.MatchOptionEquals},
						Values:       c.config.FilterByLinkedAccounts,
					},
				},
				{
					Not: &cetypes.Expression{
						Dimensions: &cetypes.DimensionValues{
							Key:          cetypes.DimensionPurchaseType,
							MatchOptions: []cetypes.MatchOption{cetypes.MatchOptionEquals},
							Values:       []string{"Refund", "Credit"},
						},
					},
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

// ListAllFiles lists all files in a bucket using the known file name prefix
func (b BucketAccess) ListAllFiles() (fileNames []string, err error) {
	iter := b.Bucket.List(&blob.ListOptions{Prefix: fileNamePrefix})
	for {
		obj, err := iter.Next(context.TODO())
		if err == io.EOF {
			break
		}
		if err != nil {
			return []string{}, fmt.Errorf("error listing files", err)
		}
		fileNames = append(fileNames, obj.Key)
	}
	return fileNames, nil
}

// NewGCSRefForConfig returns a GCS ref, given a table name
func (c AWSCostExplorerExportConfig) NewGCSRefForConfig(tableName string, set string) *bigquery.GCSReference {
	gcsRef := bigquery.NewGCSReference(
		fmt.Sprintf(bucketReferenceTemplate,
			c.BucketURI,
			fmt.Sprintf(fileNameTemplate, tableName, set)))
	gcsRef.SourceFormat = bigquery.CSV
	gcsRef.SkipLeadingRows = 1
	gcsRef.AllowJaggedRows = true
	gcsRef.AllowQuotedNewlines = true
	return gcsRef
}

// CheckIfBigQueryDatasetExists returns an error if a dataset isn't found, given a table suffix
func (c AWSCostExplorerExportConfig) CheckIfBigQueryDatasetExists(suffix string) (err error) {
	name := fmt.Sprintf(bigqueryDatasetNameTemplate, c.BigQueryManagingDatasetPrefix, suffix)
	md, err := c.bqclient.Dataset(name).Metadata(context.TODO())
	if err != nil {
		return fmt.Errorf("Dataset not found", err)
	}
	if name != md.Name {
		return fmt.Errorf("Dataset not found, names don't match '%v' != '%v'", name, md.Name)
	}
	return nil
}

// CreateBigQueryDataset creates a dataset, given a suffix
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

// DeleteBigQueryDataset deletes the tables to a dataset before deleting the dataset, given a suffix
func (c AWSCostExplorerExportConfig) DeleteBigQueryDataset(suffix string) (err error) {
	name := fmt.Sprintf(bigqueryDatasetNameTemplate, c.BigQueryManagingDatasetPrefix, suffix)
	tables, err := c.ListTablesInDataset(name)
	if err != nil {
		return err
	}
	for _, table := range tables {
		log.Printf("Deleting table '%v' in dataset '%v'", table, name)
		err = c.bqclient.Dataset(name).Table(table).Delete(context.TODO())
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

// NewSchemaForInterface returns a schema, given an interface for a schema
func (c AWSCostExplorerExportConfig) NewSchemaForInterface(obj interface{}) (schema bigquery.Schema, err error) {
	schema, err = bigquery.InferSchema(obj)
	if err != nil {
		return bigquery.Schema{}, fmt.Errorf("error inferring schema: %v", err)
	}
	return schema, nil
}

// LoadBigQueryDatasetFromGCS loads data from a GCS bucket, given a suffix and table
func (c AWSCostExplorerExportConfig) LoadBigQueryDatasetFromGCS(datasetName string, gcsRef *bigquery.GCSReference, table *Table) (err error) {
	schema, err := c.NewSchemaForInterface(table.Schema)
	if err != nil {
		return err
	}
	gcsRef.Schema = schema
	loader := c.bqclient.Dataset(datasetName).Table(string(table.Name)).LoaderFrom(gcsRef)
	loader.WriteDisposition = bigquery.WriteAppend

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
		return fmt.Errorf("job completed with error: %v\n\nerrors: %#v", status.Err(), errors)
	}
	return nil
}

// GetRowIDsFromLatestDataset returns a list of IDs, given a table name
func (c AWSCostExplorerExportConfig) GetRowIDsFromLatestDataset(table *Table) (ids []string, err error) {
	datasetName := fmt.Sprintf(bigqueryDatasetNameTemplate, c.BigQueryManagingDatasetPrefix, setLatestName)
	query := c.bqclient.Query(`SELECT DISTINCT ID FROM ` +
		fmt.Sprintf("`%v.%v`", datasetName, table.Name))
	it, err := query.Read(context.TODO())
	if err != nil {
		return []string{}, fmt.Errorf("error reading row ids", err)
	}
	for {
		var row []bigquery.Value
		err := it.Next(&row)
		if err == iterator.Done {
			break
		}
		if err != nil {
			return []string{}, fmt.Errorf("error reading row ids", err)
		}
		if row[0] == nil {
			continue
		}
		ids = append(ids, fmt.Sprint(row[0]))
	}
	return ids, nil
}

// RemoveDuplicateRows removes the rows that are duplicate in the table by ID
func (c AWSCostExplorerExportConfig) RemoveDuplicateRows(datasetName string, table *Table) (err error) {
	query := c.bqclient.Query(`
  CREATE OR REPLACE TABLE
  ` + fmt.Sprintf("`%v.%v`", datasetName, table.Name) + `AS (
  SELECT
    * EXCEPT(row_num)
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (PARTITION BY ID ORDER BY ID ) row_num
    FROM
     ` + fmt.Sprintf("`%v.%v`", datasetName, table.Name) + `) t
  WHERE
    row_num=1)`)
	job, err := query.Run(context.TODO())
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
		return fmt.Errorf("job completed with error: %v\n\nerrors: %#v", status.Err(), errors)
	}
	return nil
}

// ListTablesInDataset lists all the tables, given a dataset name
func (c AWSCostExplorerExportConfig) ListTablesInDataset(name string) (tableNames []string, err error) {
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
		tableNames = append(tableNames, t.TableID)
	}
	return tableNames, nil
}

// PromoteTablesInDatasetToLatest copies a dataset's tables over to a new dataset called latest
func (c AWSCostExplorerExportConfig) PromoteTablesInDatasetToLatest(set string) (err error) {
	datasetNameToday := fmt.Sprintf(bigqueryDatasetNameTemplate, c.BigQueryManagingDatasetPrefix, set)
	datasetNameLatest := fmt.Sprintf(bigqueryDatasetNameTemplate, c.BigQueryManagingDatasetPrefix, setLatestName)
	dsToday := c.bqclient.Dataset(datasetNameToday)
	dsLatest := c.bqclient.Dataset(datasetNameLatest)
	tables, err := c.ListTablesInDataset(datasetNameToday)
	if err != nil {
		return err
	}
	for _, table := range tables {
		job, err := dsLatest.Table(table).CopierFrom(dsToday.Table(table)).Run(context.TODO())
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
			return fmt.Errorf("job completed with error: %v\n\nerrors: %#v", status.Err(), errors)
		}
	}
	return nil
}

// FormatCostAndUsageOutputAsFileOutputs returns fileOutputs as CSV, given a costAndUsageOutput
func FormatCostAndUsageOutputAsFileOutputs(costAndUsageOutput *costexplorer.GetCostAndUsageOutput) (fileOutputs FileOutputs) {
	fileOutputs = FileOutputs{}

	dimensionValueAttributes := map[string]string{}
outerLoop:
	for _, value := range costAndUsageOutput.DimensionValueAttributes {
		for id, description := range dimensionValueAttributes {
			if *value.Value == id && value.Attributes["description"] == description {
				log.Printf("Found duplicate of '%v = %v', skipping...\n", id, description)
				continue outerLoop
			}
		}
		if value.Value == nil || *value.Value == "" {
			log.Println("Found empty value field, skipping...")
			continue outerLoop
		} else if value.Attributes["description"] == "" {
			log.Println("Found empty description field, setting as 'UNKNOWN'")
			value.Attributes["description"] = "UNKNOWN"
		}
		dimensionValueAttributes[*value.Value] = value.Attributes["description"]
	}

	resultsByTime := []ResultByTime{}
	for _, value := range costAndUsageOutput.ResultsByTime {
		for _, g := range value.Groups {
			resultByTime := ResultByTime{
				Estimated:       value.Estimated,
				Amount:          stringForStringPointer(g.Metrics["UnblendedCost"].Amount),
				Unit:            stringForStringPointer(g.Metrics["UnblendedCost"].Unit),
				TimePeriodStart: stringForStringPointer(value.TimePeriod.Start),
				TimePeriodEnd:   stringForStringPointer(value.TimePeriod.End),
				ProjectID:       g.Keys[0],
				ProjectName:     dimensionValueAttributes[g.Keys[0]],
			}
			resultByTime.ID = generateUUIDFromInterface(resultByTime)
			resultsByTime = append(resultsByTime, resultByTime)
		}
	}
	o := marshalAsCSV(resultsByTime)
	fileOutputs[string(tableResultsByTime.Name)] = o

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

	// flag.StringSliceVar?
	config.FilterByLinkedAccounts = defaultConfig.FilterByLinkedAccounts

	log.Println("Run time:", now)
	log.Println("Config:\n")
	fmt.Println(marshalAsYAML(config))

	// sleeps so that there's time to verify the config/settings for the operation about the run
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

	log.Println("Connecting to BigQuery")
	ctx := context.Background()
	client, err := bigquery.NewClient(ctx, config.GCPProjectID)
	if err != nil {
		log.Printf("error bigquery.NewClient: %v\n", err)
		return
	}
	defer client.Close()
	config.bqclient = client
	log.Println("Connected to BigQuery")

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
	for name, content := range fileOutputs {
		fileName := fmt.Sprintf(fileNameTemplate, name, now.Format(resultDateFormat))
		log.Printf("Uploading '%v' to '%v/%v'", fileName, config.BucketURI, fileName)
		err = ba.WriteToFile(fileName, content)
		if err != nil {
			log.Printf("%v", err)
			return
		}
		log.Printf("Uploaded '%v' to '%v/%v' successfully", fileName, config.BucketURI, fileName)
	}

	if !(config.BigQueryEnabled && strings.HasPrefix(config.BucketURI, "gs://")) {
		log.Println("BigQuery loading disabled or not using prefix; Complete.")
		return
	}

	set := now.Format(resultDateFormat)
	datasetName := fmt.Sprintf(bigqueryDatasetNameTemplate, config.BigQueryManagingDatasetPrefix, set)
	log.Printf("Creating dataset '%v'\n", datasetName)
	if err := config.CreateBigQueryDataset(set); err != nil {
		log.Printf("error creating new dataset '%v', %v\n", datasetName, err)
	}
	log.Printf("Created dataset '%v'\n", datasetName)
	for _, table := range tables {
		log.Printf("Loading table '%v' into dataset '%v'\n", table.Name, datasetName)
		fileNames, err := ba.ListAllFiles()
		if err != nil {
			log.Printf("error listing blob files, %v", err)
		}
		for _, fileName := range fileNames {
			setName := strings.TrimPrefix(fileName, fileNamePrefix+"-"+table.Name+"-")
			setName = strings.TrimSuffix(setName, ".csv")
			log.Printf("- loading data from '%v/%v'\n", config.BucketURI, fileName)
			gcsRef := config.NewGCSRefForConfig(string(table.Name), setName)
			err = config.LoadBigQueryDatasetFromGCS(datasetName, gcsRef, &table)
			if err != nil {
				log.Printf("error loading dataset table '%v.%v', %v\n", datasetName, table.Name, err)
			}
		}
		log.Printf("- Loaded tables '%v' successfully\n", table.Name)
		log.Printf("Removing duplicate rows from table '%v'", table.Name)
		err = config.RemoveDuplicateRows(datasetName, &table)
		if err != nil {
			log.Printf("error removing duplicate rows, %v", err)
		} else {
			log.Printf("- completed removing duplicate rows")
		}
	}
	if !config.PromoteToLatest {
		log.Println("Completed, will no promote")
		return
	}
	log.Printf("Promoting tables in dataset '%v' to latest dataset\n", datasetName)
	if err := config.DeleteBigQueryDataset(setLatestName); err != nil {
		log.Printf("error deleting dataset '%v', %v\n", setLatestName)
	} else {
		log.Printf("Deleted existing dataset '%v'\n", setLatestName)
	}
	log.Printf("Creating dataset '%v'\n", datasetName)
	if err := config.CreateBigQueryDataset(setLatestName); err != nil {
		log.Printf("error creating new dataset '%v', %v\n", datasetName, err)
	}
	if err := config.PromoteTablesInDatasetToLatest(set); err != nil {
		log.Printf("error promoting tables to latest dataset '%v', %v\n", datasetName, err)
	}
}
