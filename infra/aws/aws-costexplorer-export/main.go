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
// exports data from AWS Cost Explorer and imports it into a GCS Bucket as JSON

package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awssdkconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/costexplorer"
	cetypes "github.com/aws/aws-sdk-go-v2/service/costexplorer/types"
	"gocloud.dev/blob"
	_ "gocloud.dev/blob/fileblob"
	_ "gocloud.dev/blob/gcsblob"
	_ "gocloud.dev/blob/memblob"
	_ "gocloud.dev/blob/s3blob"
)

// consts
const (
	// formats
	usageDateFormat  = "2006-01-02"
	resultDateFormat = "200601021504"

	// templates
	fileNameTemplate = "cncf-aws-infra-billing-and-usage-data-%v.json"
)
// default config for runtime
var (
	defaultConfig = AWSCostExplorerExportConfig{
		AWSRegion: "us-east-1",
		LocalOutputFile:"/tmp/local-cncf-aws-infra-billing-and-usage-data.json",
		LocalOutputFileEnable: false,
		BucketURI: "gs://cncf-aws-infra-cost-and-billing-data",
		AmountOfDaysToReportFrom: 365,
		PromoteToLatest: true,
	}
)

func marshalAsJSON(input interface{}) string {
	o, err := json.Marshal(input)
	if err != nil {
		log.Println(err)
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

// AWSCostExplorerExportConfig stores configuration for the runtime
type AWSCostExplorerExportConfig struct {
	AWSRegion                string
	LocalOutputFile          string
	LocalOutputFileEnable    bool
	BucketURI                string
	AmountOfDaysToReportFrom int
	PromoteToLatest          bool
}

// usageClient stores the client for costexplorer
type usageClient struct {
	client *costexplorer.Client
	config AWSCostExplorerExportConfig
}

// GetInputForUsage returns an input for making the cost and usage data request
func (c usageClient) GetInputForUsage(nextPageToken *string) *costexplorer.GetCostAndUsageInput {
	start := time.Now().
		Add(-time.Duration(time.Hour * 24 * time.Duration(c.config.AmountOfDaysToReportFrom))).
		Format(usageDateFormat)
	end := time.Now().Format(usageDateFormat)
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
	for page := 0; true; page ++ {
		usage, err := c.client.GetCostAndUsage(context.TODO(), c.GetInputForUsage(nextPageToken))
		if err != nil {
			return &costexplorer.GetCostAndUsageOutput{}, fmt.Errorf("error with getting usage, %v", err)
		}
		if usage == nil {
			break
		}
		log.Printf("- page (%v): dimensions (%v); group definitions (%v); results by time (%v)\n", page, len(usage.DimensionValueAttributes), len(usage.GroupDefinitions), len(usage.ResultsByTime))
		costAndUsageOutput.DimensionValueAttributes = append(costAndUsageOutput.DimensionValueAttributes, usage.DimensionValueAttributes...)
		costAndUsageOutput.GroupDefinitions = append(costAndUsageOutput.GroupDefinitions, usage.GroupDefinitions...)
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

func main() {
	var config AWSCostExplorerExportConfig
	flag.StringVar(&config.AWSRegion, "aws-region", defaultConfig.AWSRegion, "specify an AWS region")
	flag.StringVar(&config.LocalOutputFile, "output-file", defaultConfig.LocalOutputFile, "specify a local file to write the usage JSON data to")
	flag.BoolVar(&config.LocalOutputFileEnable, "output-file-enable", defaultConfig.LocalOutputFileEnable, "specify whether the usage data is also written to disk locally")
	flag.StringVar(&config.BucketURI, "bucket-uri", defaultConfig.BucketURI, "specify a bucket to write to")
	flag.IntVar(&config.AmountOfDaysToReportFrom, "days-ago", defaultConfig.AmountOfDaysToReportFrom, "specify the amount of days back to report from today")
	flag.BoolVar(&config.PromoteToLatest, "promote-to-latest", defaultConfig.PromoteToLatest, "specifies whether to promote the cost and usage data to a latest JSON file")
	flag.Parse()

	log.Printf("Config: %#v\n", config)

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
	costAndUsageOutputJSON := marshalAsJSON(costAndUsageOutput)
	if config.LocalOutputFileEnable {
		log.Println("Writing usage data to file")
		err = writeFile(config.LocalOutputFile, costAndUsageOutputJSON)
		if err != nil {
			log.Printf("%v", err)
			return
		}
		log.Printf("Wrote usage data to file '%v'\n", config.LocalOutputFile)
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
	fileNames := []string{
		fmt.Sprintf(fileNameTemplate, time.Now().Format(resultDateFormat)),
	}
	if config.PromoteToLatest {
		fileNames = append(fileNames, fmt.Sprintf(fileNameTemplate, "latest"))
	}
	for _, fileName := range fileNames {
		log.Printf("Uploading '%v' to '%v/%v'", fileName, config.BucketURI, fileName)
		err = ba.WriteToFile(fileName, costAndUsageOutputJSON)
		if err != nil {
			log.Printf("%v", err)
			return
		}
		log.Printf("Uploaded '%v' to '%v/%v' successfully", fileName, config.BucketURI, fileName)
	}
}
