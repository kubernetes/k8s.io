#!/bin/bash

# Copyright 2022 The Kubernetes Authors.
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

# generate-audit.sh
# audits and writes the objects

# Usage:
#   ./generate-audit.sh

set -x
set -o errexit
set -o nounset
set -o pipefail

REGIONS=(
    ap-northeast-1
    ap-south-1
    ap-southeast-1

    eu-central-1
    eu-west-1

    us-east-1
    us-east-2
    us-west-1
    us-west-2
)

cd $(git rev-parse --show-toplevel)
mkdir -p ./audit/registry.k8s.io/data
cd ./audit/registry.k8s.io/data

for REGION in "${REGIONS[@]}"; do
  aws s3api list-objects --bucket "prod-registry-k8s-io-$REGION" --no-sign-request --output json > "./bucket-$REGION.json"
done
