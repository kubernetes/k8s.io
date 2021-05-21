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

# Google Secret Manager (GSM) utility functions
#
# This MUST NOT be used directly. Source it via lib.sh instead.

# Returns full name of a secret in the given project with the given secret id
# Arguments:
#   $1: The project id hosting the secret (e.g. "k8s-infra-foo")
#   $2: The secret name (e.g. "my-secret")
function secret_full_name() {
    if [ ! $# -eq 2 -o -z "$1" -o -z "$2" ]; then
        echo "secret_full_name(project, secret) requires 2 arguments" >&2
        return 1
    fi

    local project="${1}"
    local secret="${2}"

    # this command would take longer, require privileges, and fail if not found
    # gcloud secrets describe --projects ${project} ${name} --format='value(name)'
    echo "projects/${project}/secrets/${secret}"
}

# Ensures a secret exists in the given project with the given name
# Arguments:
#   $1: The project id hosting the secret (e.g. "k8s-infra-foo")
#   $2: The secret name (e.g. "my-secret")
function ensure_secret() {
    if [ ! $# -eq 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_secret(project, secret) requires 2 arguments" >&2
        return 1
    fi

    local project="${1}"
    local secret="${2}"

    if ! gcloud secrets describe --project "${project}" "${secret}" > /dev/null; then
      gcloud secrets create --project "${project}" "${secret}"
    fi
}

# Ensures a secret exists in the given project with the given name. If the
# secret does not exist, it is pre-populated with a newly created private key
# for the given service-account
# Arguments:
#   $1: The project id hosting the secret (e.g. "k8s-infra-foo")
#   $2: The secret name (e.g. "my-secret")
#   $3: The service-account (e.g. "foo@k8s-infra.iam.gserviceaccount.com")
function ensure_serviceaccount_key_secret() {
    if [ ! $# -eq 3 -o -z "$1" -o -z "$2" -o -z "$3" ]; then
        echo "ensure_serviceaccount_key_secret(project, secret, serviceaccountt) requires 3 arguments" >&2
        return 1
    fi

    local project="${1}"
    local secret="${2}"
    local serviceaccount="${3}"

    local private_key_file="${TMPDIR}/key.json"

    if ! gcloud secrets describe --project "${project}" "${secret}" > /dev/null; then
        ensure_secret "${project}" "${secret}"

        gcloud iam service-accounts keys create "${private_key_file}" \
            --project "${project}" \
            --iam-account "${serviceaccount}"

        gcloud secrets versions add "${secret}" \
            --project "${project}" \
            --data-file "${private_key_file}"
    fi
}
