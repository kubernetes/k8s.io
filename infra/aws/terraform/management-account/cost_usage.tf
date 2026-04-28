/*
Copyright 2023 The Kubernetes Authors.

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


resource "aws_cur_report_definition" "no_integrations" {
  report_name                = "k8s-infra-cur-definition"
  time_unit                  = "HOURLY"
  format                     = "textORcsv"
  compression                = "ZIP"
  additional_schema_elements = ["RESOURCES"]
  additional_artifacts       = []
  refresh_closed_reports     = true
  report_versioning          = "CREATE_NEW_REPORT"

  # S3 configuration
  s3_bucket = module.cur_reports_s3_bucket.s3_bucket_id
  s3_region = module.cur_reports_s3_bucket.s3_bucket_region
  s3_prefix = "CUR"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cur_report_definition" "athena_integration" {
  report_name                = "k8s-infra-cur-athena-definition"
  time_unit                  = "HOURLY"
  format                     = "Parquet"
  compression                = "Parquet"
  additional_schema_elements = ["RESOURCES"]
  additional_artifacts       = ["ATHENA"]
  refresh_closed_reports     = true
  report_versioning          = "OVERWRITE_REPORT"

  # S3 configuration
  s3_bucket = module.cur_reports_integration_athena_s3_bucket.s3_bucket_id
  s3_region = module.cur_reports_integration_athena_s3_bucket.s3_bucket_region
  s3_prefix = "CUR"

  lifecycle {
    create_before_destroy = true
  }
}
