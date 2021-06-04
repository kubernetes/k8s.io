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

# This is an attempt to make reviewing large audit pr changes easier, but is
# still very much a work-in-progress experiment.  The intended workflow is:
#
# - start with pending changes according to `git status`
# - run this script, which will git add/commit recognized changes
# - update the script to recognize the remaining changes
# - keep running until `git status` shows 0 files
#
# But, this is bash, so try to avoid extremely granular or hard-to-implement
# checks. If the remaining files are easy enough to review manually, do that.
#
# To setup for a run of this script against an audit PR, do the following:
#
#   git remote add cncf-ci git://github.com/cncf-ci/k8s.io.git
#   git fetch cncf-ci
#   git checkout -b my-audit-review-branch cncfi-ci/autoaudit-prow
#   git reset HEAD^

set -o errexit
set -o nounset
set -o pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
readonly REPO_ROOT

readonly AUDIT_DIR="audit"

readonly ALL_PROD_PROJECTS=(
    k8s-artifacts-prod
    k8s-artifacts-prod-bak
    k8s-cip-test-prod
    k8s-gcr-backup-test-prod
    k8s-gcr-backup-test-prod-bak
    k8s-gcr-audit-test-prod
    k8s-release-test-prod
)
PROD_PROJECT_REGEX="^$(IFS='|'; echo "${ALL_PROD_PROJECTS[*]}")$"
readonly PROD_PROJECT_REGEX

USE_GIT=true

# assume the paths passed in are relative to AUDIT_DIR
function list_files() {
    if [ "${USE_GIT}" == "true" ]; then
        # --porcelain paths are relative to REPO_ROOT, so make relative to AUDIT_DIR
        git status --porcelain "$@" | awk '{print $2}' | sed -e "s|^$AUDIT_DIR/||"
    else
        ls -1 "$@"
    fi
}

function commit_if_changes() {
    local msg="${1}"
    # mask SIGPIPE exit status from git-status if grep -q finds a match early
    if (git status --porcelain; true) | grep -q '^[AM]'; then
        git commit -m "${msg}"
    fi
}


function check_buckets() {
    local project bucket
    local location acl lifecycle logging retention
    mapfile -t files < <(
        list_files projects/*/buckets/*/metadata.txt
    )

    local staging_lifecycle='{"rule": [{"action": {"type": "Delete"}, "condition": {"age": 60}}]}'
    local release_dev_lifecycle='{"rule": [{"action": {"type": "Delete"}, "condition": {"age": 90}}]}'
    local release_pull_lifecycle='{"rule": [{"action": {"type": "Delete"}, "condition": {"age": 14}}]}'

    # anything with a # prefix is ignored
    cat >/tmp/expected_metadata <<EOF
	Storage class:			STANDARD
	Location type:			multi-region
	Location constraint:		US # ignored because policy check below
	Versioning enabled:		None
	Logging configuration:		None # ignored because policy check below
	Website configuration:		None
	CORS configuration: 		None
	Lifecycle configuration:	None # ignored because policy check below
	Requester Pays enabled:		None
	Labels:				None
	Default KMS key:		None
	Time created:			Ignored # ignored because initial import vs 'TBD'
	Time updated:			Ignored # ignored because initial import vs 'TBD'; keep ignoring due to noise?
	Metageneration:			33 # ignored because initial import vs whatever; keep ignoring due to noise?
	Bucket Policy Only enabled:	True # ignored because handled by ACL policy check; converge ACL to [] and we can stop ignoring
	ACL:				[] # ignored because policy check below
	Default ACL:			[] # ignored because handled by ACL policy check
EOF
    mapfile -t fields < <( </tmp/expected_metadata grep -v '# ignored because' | cut -d: -f1 | tr -d '\t' )
    metadata_fields_regex="\t$(IFS="|"; echo "(${fields[*]})"):"

    for f in "${files[@]}"; do
        project=$(echo "${f}" | cut -d/ -f2)
        bucket=$(echo "${f}" | cut -d/ -f4)
        actual=$(cat "${f}")

        # policy: non-US buckets should have location in name
        location=$(<${f} grep "Location constraint:" | awk '{ print $3 }')
        if [ "${location}" == "ASIA" ] && ! { [[ "${bucket}" =~ -asia ]] || [[ "${bucket}" =~ asia\. ]]; }; then
            echo "FAIL: ${project} bucket ${bucket} change location is ${location} but bucket name lacks 'asia'"; continue
        elif [ "${location}" == "EU" ] && ! { [[ "${bucket}" =~ -eu ]] || [[ "${bucket}" =~ eu\. ]]; }; then
            echo "FAIL: ${project} bucket ${bucket} change location is ${location} but bucket name lacks 'eu'"; continue
        fi

        # policy: buckets shouldn't have ACLs (means could have per-object ACLs),
        #         we want only IAM policies (uniform bucket level access)
        #
        # however, there are many buckets that don't follow this, so triage to
        # expected buckets vs unexpected
        acl=$(<${f} grep "\tACL:" | awk '{ print $2 }')
        if [ "${acl}" != "[]" ]; then
            if [[ "${bucket}" =~ ^kubernetes-staging-[0-9a-f]+ ]] \
                && {    [[ "${project}" =~ ^k8s-infra-e2e-boskos- ]] \
                    ||  [[ "${project}" == "k8s-infra-e2e-gpu-project" ]] \
                    ||  [[ "${project}" == "k8s-infra-e2e-ingress-project" ]]; }; then
                # TODO: this might be a pain to correct, but we should figure if it's possible
                #       or a blocker to enabling ubla org policy constraint
                echo "SKIP: ${project} bucket ${bucket} change has ACLs due to kube-up.sh, which is a known policy violation"
            elif [[ "${bucket}" == "artifacts.${project}.appspot.com" ]] \
                && {    [[ "${project}" =~ ^k8s-infra-e2e-boskos-scale- ]] \
                    ||  [[ "${project}" == "k8s-infra-ii-sandbox" ]] \
                    ||  [[ "${project}" == "k8s-gcr-audit-test-prod" ]]; }; then \
                # TODO: this should be corrected
                # - k8s-infra-e2e-boskos-scale-*: we should be provisioning for all e2e-projects
                # - k8s-gcr-audit-test-prod: not sure what happened here
                # - k8s-infra-ii-sandbox: was created via terraform, which I suspect doesn't do the preprovision dance that infra/gcp bash does
                echo "SKIP: ${project} bucket ${bucket} is a non-preprovisioned GCR bucket with ACLs which is a known policy violation"
            elif [[ "${bucket}" == "kubernetes_public_billing" ]] && [[ "${project}" == "kubernetes-public" ]]; then
                # TODO: this should be corrected
                echo "SKIP: ${project} bucket ${bucket} change has ACLs, which is a known policy violation"
            elif [[ "${project}" == "k8s-infra-ii-sandbox" ]]; then
                # NB: the reason this check isn't earlier is to catch the GCR policy violation above;
                #     this project was an experiment in provisioning with terraform and we should
                #     flag that as one of the shortcomings
                echo "SKIP: ${project} bucket ${bucket} change has ACLs, but is in a sandbox, so ignoring policy violations"
            else
                echo "FAIL: ${project} bucket ${bucket} change has unexpected non-empty ACL: ${acl}"; continue
            fi
        fi

        # policy: most buckets should not have lifecycles; if they do, it
        #         should be one of three well known lifecycles depending on
        #         the project name and bucket name
        lifecycle=$(<${f} grep "\tLifecycle configuration:" | awk '{ print $3 }')
        if [ "${lifecycle}" == "Present" ]; then
            lifecycle_file="projects/${project}/buckets/${bucket}/lifecycle.json"
            lifecycle=$(cat "${lifecycle_file}")
            if      [ "${lifecycle}" == "${staging_lifecycle}" ] \
                && [[ "${project}" =~ ^k8s-staging ]] \
                && {    [ "${bucket}" == "${project}-gcb" ] \
                    ||  [ "${bucket}" == "${project}" ]; }; then
                echo "PASS: ${project} bucket ${bucket} change has expected lifecycle configuration for k8s-staging projects"; git add "${lifecycle_file}"
            elif [ "${lifecycle}" == "${release_dev_lifecycle}" ] && [ "${bucket}" == "k8s-release-dev" ]; then
                echo "PASS: ${project} bucket ${bucket} change has expected lifecycle configuration for special-case: k8s-release-dev"; git add "${lifecycle_file}"
            elif [ "${lifecycle}" == "${release_pull_lifecycle}" ] && [ "${bucket}" == "k8s-release-pull" ]; then
                echo "PASS: ${project} bucket ${bucket} change has expected lifecycle configuration for special-case: k8s-release-pull"; git add "${lifecycle_file}"
            else
                echo "FAIL: $project} bucket ${bucket} change has unexpected lifecycle: ${lifecycle}"; continue
            fi
        fi

        # policy: most buckets should not have logging; if they do, it
        #         should be a well known configuration
        logging=$(<${f} grep "\tLogging configuration:" | awk '{ print $3 }')
        if [ "${logging}" == "Present" ]; then
            logging_file="projects/${project}/buckets/${bucket}/logging.json"
            logging=$(cat "${logging_file}")
            local expected_logging="{\"logBucket\": \"k8s-artifacts-gcslogs\", \"logObjectPrefix\": \"${bucket}\"}"
            if [ "${logging}" == "${expected_logging}" ]; then
                echo "PASS: ${project} bucket ${bucket} change has expected logging configuration"; git add "${logging_file}"
            else
                echo "FAIL: ${project} bucket ${bucket} change has unexpected logging: ${logging}"; continue
            fi
        fi

        # policy: most buckets should not have retention enabled; if they do,
        #         they should either be in k8s-conform, or k8s-artifacts-prod,
        #         adhering to naming conventions and durations appropriate to each
        # for whatever reason a bucket with no retention policy doesn't have
        # "None" for the field, but lacks the field entirely
        if <${f} grep -q "\tRetention Policy:.*Present"; then
            retention_file="projects/${project}/buckets/${bucket}/retention.txt"
            retention=$(<"${retention_file}" grep Duration | cut -d: -f2)
            if { { [[ "${project}" == "k8s-conform" ]] && [[ "${bucket}" =~ ^k8s-conform- ]]; } \
                || { [[ "${project}" == "k8s-artifacts-prod" ]] && [[ "${bucket}" =~ ^k8s-artifacts- ]]; } \
                || { (echo "${project}" | grep -qE "${PROD_PROJECT_REGEX}") && [[ "${bucket}" = "${project}" ]]; }; } \
                && [ "${retention}" != "10 Year(s)" ]; then
                echo "PASS: ${project} bucket ${bucket} change has expected retention ${retention}"; git add "${retention_file}"
            elif [[ "${project}" =~ ^k8s-staging ]] \
                && [[ "${bucket}" == "${project}" ]] \
                && [ "${retention}" != "30 Day(s)" ]; then
                # TODO: this should probably be corrected
                echo "SKIP: ${project} bucket ${bucket} change has incorrect retention: ${retention}, which is a known policy violation"; git add "${retention_file}"
            else
                echo "FAIL: ${project} bucket ${bucket} change has unexpected retention policy: ${retention}"; continue
            fi
        fi

        # policy: except for buckets in sandbox projects, all buckets should
        #         match a standard template, excluding the case-by-case
        #         exceptions made for specific fields above
        if [ "${project}" != "k8s-infra-ii-sandbox" ]; then
            if ! diff <(</tmp/expected_metadata grep -E "${metadata_fields_regex}") <(<${f} grep -E "${metadata_fields_regex}") >/tmp/diff.txt; then
                if [ "${project}" == "kubernetes-public" ] && </tmp/diff.txt grep -q "Storage class:"; then
                    # TODO: this should probably be corrected
                    echo "SKIP: ${project} bucket ${bucket} change has a non-default storage class, which is a known policy violation"
                elif [ "${project}" == "k8s-artifacts-prod" ] && </tmp/diff.txt grep -q "Website configuration:"; then
                    # TODO: this should probably become a hardcoded special case
                    echo "SKIP: ${project} bucket ${bucket} change has a non-default website configuration, which is known policy violation"
                else
                    echo "FAIL: ${project} bucket ${bucket} change failed to diff against expected metadata"; cat /tmp/diff.txt; continue
                fi
            fi
        fi

        # if we made it here we're good to add
        git add "${f}"
    done

    commit_if_changes "audit: expected GCS buckets"
}

function check_compute() {
    local project

    mapfile -t files < <(
        list_files projects/*/services/compute/*
    )
    for f in "${files[@]}"; do
        project=$(echo "${f}" | cut -d/ -f2)
        if [[ "${f}" =~ services/compute/clusters/[a-z-]*.json ]]; then
            echo "PASS: ${project} compute resource change ${f} is expected, auto-accepting for now"
        else
            echo "FAIL: ${project} has unexpected compute resource change: ${f}"; continue
        fi
        # if we made it here we're good to add
        git add "${f}"
    done
    commit_if_changes "audit: expected compute resource changes"
}

function check_container() {
    local project cluster cluster_tf_dir

    mapfile -t files < <(
        list_files projects/*/services/container/*
    )
    for f in "${files[@]}"; do
        project=$(echo "${f}" | cut -d/ -f2)
        if [[ "${f}" =~ services/container/clusters/[a-z-]*.json ]]; then
            cluster=$(basename ${f} .json)
            cluster_tf_dir="${REPO_ROOT}/infra/gcp/clusters/projects/${project}/${cluster}"
            if [ -d "${cluster_tf_dir}" ]; then
                echo "PASS: ${project} has container cluster resource ${cluster} is expected, auto-accepting for now"
            else
                echo "FAIL: ${project} has unexpected cluster: ${cluster}"; continue
            fi
        else
            echo "FAIL: ${project} has unexpected container resource change: ${f}"; continue
        fi
        # if we made it here we're good to add
        git add "${f}"
    done
    commit_if_changes "audit: expected container resource changes"
}

function check_iam_in_projects() {
    local project

    mapfile -t files < <(
        list_files projects/*/iam.json
        list_files projects/*/service-accounts/*
    )
    for f in "${files[@]}"; do
        project=$(echo "${f}" | cut -d/ -f2)
        if [ "$(basename "${f}")" == "iam.json" ]; then
            echo "FAIL: ${project} has unexpected iam policy-binding resource change: ${f}"; continue
        else
            echo "FAIL: ${project} has unexpected service-account resource change: ${f}"; continue
        fi
        # if we made it here we're good to add
        git add "${f}"
    done
    commit_if_changes "audit: expected iam resource changes"
}

function check_logging() {
    local project actual

    mapfile -t files < <(
        list_files projects/*/services/logging/*
    )
    for f in "${files[@]}"; do
        project=$(echo "${f}" | cut -d/ -f2)
        case "$(basename ${f})" in
        metrics.json)
            actual=$(cat ${f})
            if [ "${actual}" == "[]" ]; then
                # TODO: this should be corrected
                echo "SKIP: ${project} has empty logging metrics change, which is a known policy violation"
            else
                echo "FAIL: ${project} has unexpected logging metrics change: ${actual}"; continue
            fi
            ;;
        logs.json)
            if [[ "${project}" =~ k8s-infra-e2e ]]; then
                echo "SKIP: ${project} has noisy log resource changes due to e2e-tests, auto-accepting for now"
            elif ! grep -q '/cloudaudit.googleapis.com%2Factivity' "${f}"; then
                echo "FAIL: ${project} log resource change missing audit activity log: ${f}"; continue
            elif ! grep -q '/cloudaudit.googleapis.com%2Fsystem_event' "${f}"; then
                echo "FAIL: ${project} log resource change missing audit system_event log: ${f}"; continue
            else
                echo "FAIL: TODO: ${project} has unexpected logs resource change: ${f}"; continue
            fi
            ;;
        sinks.json)
            echo "FAIL: TODO: ${project} has unexpected logs resource change: ${f}"; continue
            ;;
        *)
            echo "FAIL: ${f} is an unrecognized logging resource change"
            ;;
        esac
        # if we made it here we're good to add
        git add "${f}"
    done

    commit_if_changes "audit: expected logging resource"
}

function check_monitoring() {
    local project actual

    mapfile -t files < <(
        list_files projects/*/services/monitoring/*
    )
    for f in "${files[@]}"; do
        project=$(echo "${f}" | cut -d/ -f2)
        if [ "${project}" == "k8s-infra-prow-build" ] && [[ "${f}" =~ services/monitoring/dashboards/[a-z-]*.json ]]; then
            echo "PASS: ${project} monitoring resource ${f} is expected, auto-accepting for now"
        else
            echo "FAIL: ${project} has unexpected monitoring resource change: ${f}"; continue
        fi
        # if we made it here we're good to add
        git add "${f}"
    done
    commit_if_changes "audit: expected monitoring resource changes"
}

function check_organization() {
    local org

    mapfile -t files < <(
        list_files organizations/*
    )
    for f in "${files[@]}"; do
        org=$(echo "${f}" | cut -d/ -f2)
        if [ "${f}" == "organizations/kubernetes.io/description.json" ]; then
            echo "PASS: ${org} resource ${f} is expected, auto-accepting for now"
        elif [[ "${f}" =~ organizations/kubernetes.io/roles/.*.json ]]; then
            role=$(basename "${f}" .json)
            role_yaml="${REPO_ROOT}/infra/gcp/roles/${role}.yaml"
            # TODO: yq means can't use releng-ci for this
            <"${role_yaml}" yq ".name |= \"organizations/758905017065/roles/${role}\"" > /tmp/expected.json
            if diff /tmp/expected.json "${f}" >/tmp/diff.txt; then
                echo "PASS: organization ${org} iam role resource change to ${role} matches expected ${role_yaml}"
            else
                echo "FAIL: organization ${org} iam role resource change to ${role} differs from expected ${role_yaml}..."
                cat /tmp/diff.txt
                continue
            fi
        else
            echo "FAIL: organization ${org} has unexpected resource change: ${f}"; continue
        fi
        # if we made it here we're good to add
        git add "${f}"
    done
    commit_if_changes "audit: expected organization resource changes"
}

function main() {
    pushd "${REPO_ROOT}/${AUDIT_DIR}" >/dev/null

    check_buckets
    check_compute
    check_container
    check_iam_in_projects
    check_logging
    check_monitoring
    check_organization

    # git status --porcelain
    echo "$(git status --porcelain | wc -l) files remaining"

    popd >/dev/null
}

main "$@"