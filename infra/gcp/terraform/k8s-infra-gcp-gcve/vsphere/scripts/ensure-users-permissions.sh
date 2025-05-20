#!/bin/bash

# Copyright 2025 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

GCVE_PROW_CI_GROUP="prow-ci-group"

# set some global permissions which can't be done using terraform due to the following bug:
# https://github.com/vmware/terraform-provider-vsphere/issues/2078

# Enable searching for existing PVC's and top-level read permissions.
govc permissions.ls / | grep ${GCVE_PROW_CI_GROUP} | grep -q vsphere-ci-readonly || (govc permissions.set -propagate=false -group -principal GVE.LOCAL\\${GCVE_PROW_CI_GROUP} -role vsphere-ci-readonly / && echo "Added permissions for ${GCVE_PROW_CI_GROUP} as vsphere-ci-readonly to /")

# Enable searching for VM's and top-level read permissions.
govc permissions.ls /Datacenter | grep ${GCVE_PROW_CI_GROUP} | grep -q ReadOnly || (govc permissions.set -propagate=false -group -principal GVE.LOCAL\\${GCVE_PROW_CI_GROUP} -role ReadOnly /Datacenter && echo "Added permissions for ${GCVE_PROW_CI_GROUP} as ReadOnly to /Datacenter")

# Enable read for DistributedVirtualSwitch
govc permissions.ls /Datacenter/network/Datacenter-dvs | grep ${GCVE_PROW_CI_GROUP} | grep -q ReadOnly || (govc permissions.set -propagate=false -group -principal GVE.LOCAL\\${GCVE_PROW_CI_GROUP} -role ReadOnly /Datacenter/network/Datacenter-dvs && echo "Added permissions for ${GCVE_PROW_CI_GROUP} as ReadOnly to /Datacenter/network/Datacenter-dvs")

# Enable vsphere-ci for datastore
govc permissions.ls /Datacenter/datastore/vsanDatastore | grep ${GCVE_PROW_CI_GROUP} | grep -q ReadOnly || (govc permissions.set -propagate=false -group -principal GVE.LOCAL\\${GCVE_PROW_CI_GROUP} -role vsphere-ci /Datacenter/datastore/vsanDatastore && echo "Added permissions for ${GCVE_PROW_CI_GROUP} as vsphere-ci to /Datacenter/datastore/vsanDatastore")

# Allow access to content libraries
govc sso.group.ls "RegistryAdministrators" | grep -q "${GCVE_PROW_CI_GROUP}" || (govc sso.group.update -g -a "${GCVE_PROW_CI_GROUP}" "RegistryAdministrators" && echo "Added group ${GCVE_PROW_CI_GROUP} to group RegistryAdministrators")
