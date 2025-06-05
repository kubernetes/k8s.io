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

# Adds all users from the group k8s-infra-gcp-gcve-admins to the essential contacts of the project.
# This allows receiving notifications for updates, etc. for VMware Engine.
# xref: https://cloud.google.com/vmware-engine/docs/concepts-monitoring#email-notifications

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../.." && pwd -P)
readonly REPO_ROOT

GCLOUD_PROJECT_ID=broadcom-451918

for mail in $(cat "${REPO_ROOT}/groups/sig-k8s-infra/groups.yaml" | yq -r '.groups[] | select(.name == "k8s-infra-gcp-gcve-admins") | .members[] | select(. | contains "@kubernetes.io" | not)'); do
  echo "> Ensuring ${mail} exists as essential contact"
  ENTRIES="$(gcloud essential-contacts list --filter "email=${mail}" --format=json  | jq '. | length')"
  if [[ $ENTRIES -eq 0 ]]; then
    echo "Creating ${mail} as technical essential contact"
    gcloud essential-contacts create --language=en-US --notification-categories=legal,product-updates,security,suspension,technical --project "${GCLOUD_PROJECT_ID}" "--email=${mail}"
  elif [[ $ENTRIES -eq 1 ]]; then
    echo "Contact already exists"
  else
    echo "ERROR: checking ${mail}, too many results"
    exit 1
  fi
done
