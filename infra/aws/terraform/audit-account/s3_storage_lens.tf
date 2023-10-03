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

/*
This file contains:
- configuration for S3 Storage Lens at the organization level
*/

resource "aws_s3control_storage_lens_configuration" "main" {
  provider  = aws.audit
  config_id = "k8s-infra-s3-lens"

  storage_lens_configuration {
    enabled = true

    account_level {
      activity_metrics {
        enabled = true
      }

      bucket_level {
        activity_metrics {
          enabled = true
        }
      }
    }

    aws_org {
      arn = data.aws_organizations_organization.current.arn
    }

    data_export {
      # Metrics are published once a day.
      # See: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-lens-cloudwatch-enable-publish-option.html
      cloud_watch_metrics {
        enabled = true
      }
    }
  }

  tags = merge({
    env       = "Audit",
    component = "Security",
    service   = "S3 Storage Lens"
  }, var.tags)
}
