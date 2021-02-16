#!/usr/bin/env bash
#
# Copyright 2019 The Kubernetes Authors.
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

# This script ensures permissions for k8s-infra-gcp-auditor group

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0 [repo...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all staging repos" > /dev/stderr
    echo "  $0 coredns # just do one" > /dev/stderr
    echo > /dev/stderr
}

color 6 "Ensuring k8s-infra-gcp-auditor iam rolebindings:"

GROUP=group:k8s-infra-gcp-auditor@kubernetes.io
ROLES="organizations/758905017065/roles/StorageBucketLister
roles/compute.viewer
roles/dns.reader
roles/iam.securityReviewer
roles/resourcemanager.organizationViewer
roles/secretmanager.viewer
roles/serviceusage.serviceUsageConsumer"

for ROLE in $ROLES
do
    gcloud organization add-iam-policy-binding \
           --member=$GROUP \
           --role=$ROLE
done
