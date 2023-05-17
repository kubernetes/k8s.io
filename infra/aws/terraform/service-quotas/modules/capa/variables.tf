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

variable "capa_quotas" {
  type = map(object({
    quota_code   = string
    service_code = string
    value        = number
  }))
  default = {
    # Amazon EventBridge (CloudWatch Events): Maximum number of rules an account can have per event bus
    "events_rules" = {
      quota_code   = "L-244521F2"
      service_code = "events"
      value        = 500
    }
    # Amazon Virtual Private Cloud (Amazon VPC): The maximum number of VPCs per Region.
    # This quota is directly tied to the maximum number of internet gateways per Region.
    "vpc_max_vpcs" = {
      quota_code   = "L-F678F1CE"
      service_code = "vpc"
      value        = 25
    }
    # Amazon Virtual Private Cloud (Amazon VPC): The maximum number of NAT gateways per Availability Zone.
    # This includes NAT gateways in the pending, active, or deleting state.
    "vpc_max_nat_gateways" = {
      quota_code   = "L-FE5A380F"
      service_code = "vpc"
      value        = 20
    }
    # Amazon Virtual Private Cloud (Amazon VPC): The maximum number of internet gateways per Region.
    # This quota is directly tied to the maximum number of VPCs per Region. To increase this quota, increase the number of VPCs per Region.
    "vpc_max_internet_gateways" = {
      quota_code   = "L-A4707A72"
      service_code = "vpc"
      value        = 25
    }
    # Amazon Elastic Compute Cloud (Amazon EC2): The maximum number of Elastic IP addresses that you can allocate for EC2-VPC in this Region.
    "ec2_max_elastic_ips" = {
      quota_code   = "L-0263D0A3"
      service_code = "ec2"
      value        = 100
    }
    # Amazon Elastic Compute Cloud (Amazon EC2): Maximum number of vCPUs assigned to the Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances.
    "ec2_max_vcpus" = {
      quota_code   = "L-1216C47A"
      service_code = "ec2"
      value        = 128
    }
    # Amazon Elastic Compute Cloud (Amazon EC2): Maximum number of vCPUs assigned to the Running On-Demand G and VT instances.
    "ec2_max_vcpus_g_vt" = {
      quota_code   = "L-DB2E81BA"
      service_code = "ec2"
      value        = 8
    }
  }
}
