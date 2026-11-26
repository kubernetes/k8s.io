/*
Copyright 2026 The Kubernetes Authors.

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


module "cdn" {
  source = "../cdn"
  domain = "pkgs.k8s.io"
  datadog_config = {
    token        = data.google_secret_manager_secret_version_access.datadog_api_key.secret_data,
    service_name = "pkgs.k8s.io",
    env          = "prod",
  }
  access_key = data.google_secret_manager_secret_version_access.s3_reader_access_key.secret_data
  secret_key = data.google_secret_manager_secret_version_access.s3_reader_secret_key.secret_data

  cloud           = "aws"
  aws_region      = "eu-central-1"
  shield_location = "frankfurt-de" # closest shield to eu-central-1

  # Managed in infra/aws/terraform/cdn.packages.k8s.io
  bucket_configs = [
    { name = "prod-cdn-packages-k8s-io-eu-central-1" },
  ]
}
