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

output "capa_quotas_adjustable" {
  value = {
    "eks-e2e-boskos-001" = module.capa_quotas_001.quotas_adjustable
    "eks-e2e-boskos-002" = module.capa_quotas_002.quotas_adjustable
    "eks-e2e-boskos-003" = module.capa_quotas_003.quotas_adjustable
    "eks-e2e-boskos-004" = module.capa_quotas_004.quotas_adjustable
    "eks-e2e-boskos-005" = module.capa_quotas_005.quotas_adjustable
    "eks-e2e-boskos-006" = module.capa_quotas_006.quotas_adjustable
    "eks-e2e-boskos-007" = module.capa_quotas_007.quotas_adjustable
    "eks-e2e-boskos-008" = module.capa_quotas_008.quotas_adjustable
    "eks-e2e-boskos-009" = module.capa_quotas_009.quotas_adjustable
    "eks-e2e-boskos-010" = module.capa_quotas_010.quotas_adjustable
  }
  description = "List of adjustable attributes for each CAPA quota"
}
