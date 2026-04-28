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

terraform {
  required_version = "~> 1.5.0"

  backend "s3" {
    bucket = "k8s-infra-tf-shared-services"
    key    = "infrastructure-services/terraform.tfstate"
    region = "us-east-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.7"
    }
  }
}

locals {
  name = "external-dependency-health-checks"
  external_dependency_health_checks_targets = {
    google_cloud_pkgs_apt_gpg = {
      name          = "google-cloud-pkgs"
      fqdn          = "packages.cloud.google.com"
      resource_path = "/apt/doc/apt-key.gpg"
    }
  }
  emails = [
    "k8s-infra-alerts@kubernetes.io"
  ]
  sns_topic_delivery_policy = jsonencode({
    "http" : {
      "defaultHealthyRetryPolicy" : {
        "minDelayTarget" : 20,
        "maxDelayTarget" : 20,
        "numRetries" : 3,
        "numMaxDelayRetries" : 0,
        "numNoDelayRetries" : 0,
        "numMinDelayRetries" : 0,
        "backoffFunction" : "linear"
      },
      "disableSubscriptionOverrides" : false,
      "defaultThrottlePolicy" : {
        "maxReceivesPerSecond" : 1
      }
    }
  })
}

module "external_dependency_sns_topic" {
  source          = "../modules/sns/sns-topic"
  name            = local.name
  delivery_policy = local.sns_topic_delivery_policy
}

module "external_dependency_sns_subscribe_emails" {
  source        = "../modules/sns/sns-subscribe-email"
  name          = local.name
  emails        = local.emails
  sns_topic_arn = module.external_dependency_sns_topic.sns_topic_arn
}

module "external_dependency_health_checks" {
  for_each      = local.external_dependency_health_checks_targets
  source        = "../modules/external-resource-health-check/https-health-check"
  name          = each.value["name"]
  fqdn          = each.value["fqdn"]
  resource_path = each.value["resource_path"]
  sns_arn       = module.external_dependency_sns_topic.sns_topic_arn
}
