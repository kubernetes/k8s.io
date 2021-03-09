#!/usr/bin/env bash

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

# This script creates namespaces, applies roles and role bindings and
# checks if assigned role binding is the only one in the namespace
# for k8s-infra projects

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")
# shellcheck source=../lib.sh
. "${SCRIPT_DIR}/lib.sh"

NAMESPACE_FILENAME="namespace.yml"
ROLE_FILENAME="namespace-user-role.yml"
ROLE_BINDING_FILENAME="namespace-user-role-binding.yml"

function usage() {
    echo "usage: $0 <cluster> [--kubectl-path ...] [--kubeconfig-path ...]" >&2
    echo "       --kubectl-path    | -p      path to kubectl command if not in \$PATH [optional]" >&2
    echo "       --kubeconfig-path | -k      path to kubeconfig if not in: $HOME/.kube/config [optional]" >&2
    echo "example: $0 my-cluster --kubectl-path /custom/path/kubectl --kubeconfig-path /custom/path/kubeconfig"
    echo >&2
}

function parse_args() {
  # positional args
  args=()

  # named args
  while [ "$#" -gt 0 ]; do
      case "$1" in
          -p | --kubectl-path )         KUBECTL="$2";            shift;;
          -k | --kubeconfig-path )      KUBECONFIG_PATH="$2";    shift;;
          * )                           args+=("$1")             # if no match, add it to the positional args
      esac
      shift # move to next kv pair
  done

  # restore positional args
  set -- "${args[@]}"

  # set defaults
  if [[ -z "${KUBECONFIG_PATH:-}" ]]; then
      KUBECONFIG_PATH="$HOME/.kube/config";
  fi

  if [[ -z "${KUBECTL:-}" ]]; then
    if ! [ -x "$(command -v kubectl)" ]; then
      echo "kubectl not found in \$PATH and --kubectl-path flag is not set. Aborting." >&2;
      exit 1;
    else
      KUBECTL="kubectl"
    fi
  fi

  if [ "${#args[@]}" -ne 1 ]; then
    usage
    exit 1
  fi

  CLUSTER="${args[0]}"
}

function apply_namespace() {
  if [ $# != 1 ]; then
    echo "apply_namespace(name) requires 1 argument" >&2
    return 1
  fi
  namespace="$1"

  sed -e "s/{{name}}/${namespace}/" "$NAMESPACE_FILENAME" \
      | "$KUBECTL" apply --cluster="$CLUSTER" --kubeconfig "$KUBECONFIG_PATH" -f -
}

function apply_role() {
  if [ $# != 1 ]; then
    echo "apply_role(name) requires 1 argument" >&2
    return 1
  fi
  project_name="$1"
  namespace="$project_name"

  sed -e "s/{{namespace}}/$project_name/" "$ROLE_FILENAME" \
    | "$KUBECTL" apply --cluster="$CLUSTER" --kubeconfig "$KUBECONFIG_PATH" -n "$namespace" -f -
}

function apply_role_binding() {
  if [ $# != 1 ]; then
    echo "apply_role_binding(name) requires 1 argument" >&2
    return 1
  fi
  project_name="$1"
  namespace="$project_name"

  sed -e "s/{{namespace}}/$project_name/" "$ROLE_BINDING_FILENAME" \
    | "$KUBECTL" apply --cluster="$CLUSTER" --kubeconfig "$KUBECONFIG_PATH" -n "$namespace" -f -
}

function ensure_only_one_proper_role_binding() {
  if [ $# != 1 ]; then
    echo "ensure_only_one_proper_role_binding(name) requires 1 argument" >&2
    return 1
  fi
  project_name="$1"
  namespace="$project_name"
  role_bindings_count=$("$KUBECTL" get rolebindings --cluster="$CLUSTER" --kubeconfig "$KUBECONFIG_PATH" -o json -n "$namespace" \
    | jq -r '.items | length')

  if [ "$role_bindings_count" -gt 1 ]; then
    echo "Only one role binding per namespace is allowed (current: $role_bindings_count)"
    exit 1
  fi

  role_binding_name=$("$KUBECTL" get rolebindings --cluster="$CLUSTER" --kubeconfig "$KUBECONFIG_PATH" -o json -n "$namespace" \
    | jq -r '.items[0].metadata.name')

  if [ "$role_binding_name" != "namespace-user" ]; then
    echo "Expected role binding: 'namespace-user', got: '$role_binding_name'"
    exit 1
  fi
}

parse_args "$@";

#
# Project names
#

ALL_PROJECTS=(
    "gcsweb"
    "k8s-io-prod"
    "k8s-io-canary"
    "node-perf-dash"
    "perfdash"
    "prow"
    "publishing-bot"
    "slack-infra"
    "triageparty-release"
    "wg-reliability-sippy"
)

for prj in "${ALL_PROJECTS[@]}"; do
    color 6 "Create namespace: ${prj}"
    apply_namespace "${prj}"

    color 6 "Apply namespace-user role: ${prj}"
    apply_role "${prj}"

    color 6 "Apply namespace-user role binding: ${prj}"
    apply_role_binding "${prj}"

    color 6 "Ensure only one role binding in namespace: ${prj} is present"
    ensure_only_one_proper_role_binding "${prj}"
done

color 6 "Done"
