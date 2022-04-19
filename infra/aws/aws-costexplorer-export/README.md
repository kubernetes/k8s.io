# Introduction

In the k8s-infra community, data for billing on projects in the org is collated into a billing report which is viewed each meeting. Currently that data is only pulled from the GCP org.

# Goal

- Pull in CostExplorer usage & cost data for the last year
- Prepare it
  - Transform the data if need be
  - Marshal as CSV
- Upload the CSV data into a bucket
- Load data into BigQuery

# Operation

- Get a CostExplorer client through AWS SDK
- Fetch the usage data
- Prepare usage data
  - Marshal usage data as CSV
- Open a connection to a bucket (GCS Bucket)
- Upload prepared data to the bucket
  - using name based on date+time
- Create a BigQuery dataset based on date+time
- Load all CSV files from bucket into the BigQuery dataset
- Promote the dataset tables to new dataset called latest by copying them

# Preparation

## Log into AWS

Configure the local CLI for access

```bash
aws configure
```

NOTE: An org-level root account or IAM account with CostExplorer access is required

## Log into GCP

Account log in

```bash
gcloud auth login
```

Set the project to _k8s-infra-ii-sandbox_

```bash
gcloud config set project k8s-infra-ii-sandbox
```

Log into application-default CloudSDK

```bash
gcloud auth application-default login
```

# Usage

```shell
go run .
```

## Flags

| Name                             | Default                                              | Description                                            |
| -------------------------------- | ---------------------------------------------------- | ------------------------------------------------------ |
| aws-region                       | us-east-1                                            | region for AWS SDK to use                              |
| output-file                      | /tmp/local-cncf-aws-infra-billing-and-usage-data.csv | a temporary location to write the usage data           |
| output-file-enable               | false                                                | whether the usage data is also written to disk locally |
| bucket-uri                       | gs://cncf-aws-infra-cost-and-billing-data            | the bucket to upload the csv blobs to                  |
| days-back                        | 365                                                  | the amount of days back to report from today           |
| promote-to-latest                | true                                                 | promotes the cost and usage data to a latest CSV file  |
| bigquery-enabled                 | true                                                 | load data into BigQuery from the specified bucket      |
| bigquery-data-location           | australia-southeast1                                 | the BigQuery dataset location                          |
| bigquery-managing-dataset-prefix | cncf aws infra cost and billing data dataset         | a prefix to use for managing BigQuery datasets         |

# Testing

Use an in-memory S3 style bucket and write the usage data also to local disk

```shell
go run . \
    --bucket-uri "mem://" \
    --output-file-enable=true
```

# Build an image

Produce a container image using ko

```bash
ko publish --local .
```

# Links

- <https://pkg.go.dev/cloud.google.com/go/bigquery>
- <https://pkg.go.dev/github.com/aws/aws-sdk-go-v2/service/costexplorer@v1.15.0#GetCostAndUsageOutput>
