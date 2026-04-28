#!/usr/bin/env bash

# Copyright 2023 The Kubernetes Authors.
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

## This script is used to list pods running on nodes that match the given
## node label selector

set -euo pipefail

# Check if the node label selector is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <node-label-selector>"
    exit 1
fi

NODE_LABEL_SELECTOR=$1

# Get the list of Nodes that match given node label selector
NODES=$(kubectl get nodes --selector="${NODE_LABEL_SELECTOR}" -o jsonpath='{.items[*].metadata.name}')

# Iterate through the list of nodes and print Running Pods in test-pods namespace
for NODE in $NODES; do
    POD_COUNT=$(kubectl get pods --namespace test-pods --field-selector=spec.nodeName="${NODE}",status.phase=Running -o jsonpath='{.items[*].metadata.name}' | wc -w)
    
    # Only print pods for node if there are pods running on that node
    if [ "$POD_COUNT" -gt 0 ]; then
        echo "${NODE}:"
        kubectl get pods --namespace test-pods --field-selector=spec.nodeName="${NODE}",status.phase=Running --no-headers
        echo "------------------------------------"
    fi
done
