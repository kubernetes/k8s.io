#!/usr/bin/env bash

# Copyright 2024 The Kubernetes Authors.
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

set -e

if [[ "${DEBUG}" == "true" ]]; then
  set -x
fi

# TODO: ensure govc
# TODO: ensure all env vars are set
# TODO: set pipefail, etc.

GITHUB_CA_CERTIFICATE_JSON='{"cert_chain": {"cert_chain": ["'${GITHUB_CA_CERTIFICATE}'"]}}'

# Ensure the githubs CA certificate exists

echo "> Ensuring githubs CA certificate exists so library imports work"

if [[ "$(govc session.login -r -X GET "/api/vcenter/certificate-management/vcenter/trusted-root-chains" | grep -e "${GITHUB_CA_THUMBPRINT}")" == "" ]]; then
  govc session.login -r -X POST "/api/vcenter/certificate-management/vcenter/trusted-root-chains" <<< ${GITHUB_CA_CERTIFICATE_JSON}
fi

function ensureOVA() {
  URL="${1}"
  NAME=${URL##*/}
  NAME=${NAME%.ova}

  echo "> Ensuring OVA ${NAME} from ${URL} exists"

  if [[ "$(govc library.info "/${CONTENT_LIBRARY_NAME}/${NAME}" || true)" == "" ]]; then
    echo ">> in content library /${CONTENT_LIBRARY_NAME}"
    govc library.import -pull "/${CONTENT_LIBRARY_NAME}" "${URL}"
  fi

  if [[ "$(govc vm.info "${TEMPLATES_FOLDER}/${NAME}" || true)" == "" ]]; then
    echo ">> as VM template in ${TEMPLATES_FOLDER}"
    govc library.deploy -folder "${TEMPLATES_FOLDER}" -ds "${DATASTORE}" -pool "${RESOURCE_POOL}" "/${CONTENT_LIBRARY_NAME}/${NAME}"
    govc snapshot.create -vm "${TEMPLATES_FOLDER}/${NAME}" "for-linkedclone"
    govc vm.markastemplate "${TEMPLATES_FOLDER}/${NAME}"
  fi
}

echo "> Ensuring OVA from ${URL}"

ensureOVA "${URL}"
