#!/usr/bin/env bash

# Copyright 2021 The Kubernetes Authors.
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

# Utility functions for reading / validating data from infra/gcp/infra.yaml

# This MUST NOT be used directly. Source it via lib.sh instead.

INFRA_YAML="$(dirname "${BASH_SOURCE[0]}")/infra.yaml"
readonly INFRA_YAML

# Echo the name of the given project if it has been
# declared in infra.yaml, otherwise return an error
#
# $1: The "type" of the project, e.g. "staging"
# $2: The id of the project, e.g. "k8s-infra-foo"
function k8s_infra_project() {
    if [ $# != 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "${FUNCNAME[0]}(project_type, project) requires 2 arguments" >&2
        return 1
    fi
    local project_type="${1}"
    local project="${2}"
    if <"${INFRA_YAML}" yq --exit-status ".infra.${project_type}.projects | has(\"${project}\")" >/dev/null; then
        echo "${project}"
    else
        color 1 "ERROR: undeclared ${project_type} project: ${project}" >&2
        return 1
    fi
}

# Echo the names of all projects of the given project_type as
# declared in infra.yaml
#
# $1: The "type" of the project, e.g. "staging"
function k8s_infra_projects() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(project_type) requires 1 arguments" >&2
        return 1
    fi
    local project_type="${1}"
    <"${INFRA_YAML}" yq --raw-output ".infra.${project_type}.projects | keys[]"
}
