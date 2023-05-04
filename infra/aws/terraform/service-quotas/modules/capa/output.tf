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

output "events_rules_adjustable" {
  value = aws_servicequotas_service_quota.events_rules.adjustable
}

output "vpc_max_vpcs_adjustable" {
  value = aws_servicequotas_service_quota.vpc_max_vpcs.adjustable
}

output "vpc_max_nat_gateways_adjustable" {
  value = aws_servicequotas_service_quota.vpc_max_nat_gateways.adjustable
}

output "vpc_max_internet_gateways_adjustable" {
  value = aws_servicequotas_service_quota.vpc_max_internet_gateways.adjustable
}

output "ec2_max_elastic_ips_adjustable" {
  value = aws_servicequotas_service_quota.ec2_max_elastic_ips.adjustable
}

output "ec2_max_vcpus_adjustable" {
  value = aws_servicequotas_service_quota.ec2_max_vcpus.adjustable
}

output "ec2_max_vcpus_g_vt_adjustable" {
  value = aws_servicequotas_service_quota.ec2_max_vcpus_g_vt.adjustable
}
