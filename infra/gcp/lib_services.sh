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

# GCP Services utility functions
#
# This is intended to be very general-purpose and "low-level".  Higher-level
# policy does not belong here.
#
# This MUST NOT be used directly. Source it via lib.sh instead.

# Enable an API
# $1:  The GCP project
# $2+: The APIs to enable (e.g. containerregistry.googleapis.com)
function enable_api() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "${FUNCNAME[0]}(gcp_project, service...) requires at least 2 arguments" >&2
        return 1
    fi
    local project="$1"; shift
    local services=("${@}")

    for s in "${services[@]}"; do
        gcloud --project "${project}" services enable "${s}"
    done
}

readonly services_plan_jq="${TMPDIR}/services_plan.jq"
function _ensure_services_plan_jq() {
    if [ -f "${services_plan_jq}" ]; then return; fi
    # quote EOF to avoid $expansion in here-document
    >"${services_plan_jq}" cat <<"EOF"
    ($ARGS.positional | sort) as $intent | {
      intent: $intent,
      enabled: map(.config.name) | sort,
      expected: (
        map(
          select([.config.name] | inside($intent))
          | (.dependencyConfig?.directlyDependsOn // [])
        ) + $intent
      )
      | flatten
      | map({key:., value:true}) | from_entries | keys | sort
    } | . += {
      to_enable: (.expected - .enabled),
      to_disable: (.enabled - .expected)
    }
EOF
}

# Output a plan of services to enable/disable for a given gcp project; format
# is YAML, each key is a list of services e.g. [pubsub.googleapis.com, ...]
#   intent:     # services we wish to enable
#   enabled:    # services that are presently enabled
#   expected:   # intent + any services directly depended on by intent
#   to_enable:  # services in intent that are not enabled
#   to_disable: # services that are enabled but not in expected
# $1  The GCP project
# $2+ Service names that are expected to be enabled (e.g. pubsub.googleapis.com)
function _plan_enabled_services() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "${FUNCNAME[0]}(gcp_project, service...) requires at least 2 arguments" >&2
        return 1
    fi

    local gcp_project="$1"; shift

    _ensure_services_plan_jq

    gcloud services list --enabled --project="${gcp_project}" \
      --format='yaml(config.name,dependencyConfig.directlyDependsOn)' \
      | yq --slurp -y --args --from-file "${services_plan_jq}" "$@"
}

# Ensure that only the given services and their direct dependencies are enabled; disable any other services
# $1  The GCP project for which to enable/disable services
# $2+ The service names (e.g. pubsub.googleapis.com)
function ensure_only_services() {
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "${FUNCNAME[0]}(gcp_project, service...) requires at least 2 arguments" >&2
        return 1
    fi

    local gcp_project="$1"; shift

    local before="${TMPDIR}/ensure-only-services.before.yaml"
    local after_enable="${TMPDIR}/ensure-only-services.after_enable.yaml"
    local after_disable="${TMPDIR}/ensure-only-services.after_disable.yaml"

    # get services before modifying to diff against when finished
    _plan_enabled_services "${gcp_project}" "$@" > "${before}"

    # if there's nothing to do, return early
    if ! <"${before}" yq --exit-status '[.to_enable, .to_disable] | map (length > 0) | any' >/dev/null; then
      return
    fi

    echo "plan to enable/disable the following services"
    <"${before}" yq -y '{to_enable, to_disable}'

    # enable services that need to be enabled
    for service in $(<"${before}" yq -r '.to_enable[]'); do
        gcloud services enable --project="${gcp_project}" "${service}"
    done

    # disable services not explicitly enabled or directly required
    _plan_enabled_services "${gcp_project}" "$@" > "${after_enable}"


    # TODO(spiffxp): get comfortable with --force or redo to disable in dep-order;
    #                until then, set an obnoxiously long env var to actually disable
    local disable_cmd='echo "INFO: dry-run mode, would run:" gcloud'
    if [ "${K8S_INFRA_ENSURE_ONLY_SERVICES_WILL_FORCE_DISABLE:-""}" == "true" ]; then
        disable_cmd=gcloud
    fi
    for service in $( (<"${after_enable}" yq -r '.to_disable[]') | sort | uniq -u); do
        ${disable_cmd} services disable --force "${service}" --project="${gcp_project}"
    done

    _plan_enabled_services "${gcp_project}" "$@" > "${after_disable}"

    # in the event that an enable/disable cycle doesn't do enough, let's warn
    if <"${after_disable}" yq --exit-status '[.to_enable, .to_disable] | map (length > 0) | any' >/dev/null; then
      echo "WARN: ensure_only_services: after enable/disable cycle, still projects to enable/disable: ${gcp_project}"
      cat "${after_disable}"
    fi

    diff_colorized "${before}" "${after_disable}"
}
