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

GOVC_FOLDER="/Datacenter/vm/prow/templates"
OVC_DATASTORE="vsanDatastore"
VCENTER_NETWORK_NAME=k8s-ci
export GOVC_FOLDER
export OVC_DATASTORE
export VCENTER_NETWORK_NAME

function checkIfExists() {
  OVA_TEMPLATE_NAME="${1}"
  if govc ls "${GOVC_FOLDER}/${OVA_TEMPLATE_NAME}" | grep -q "$OVA_TEMPLATE_NAME$"; then
    echo "ERROR: OVA already exists at ${GOVC_FOLDER}/${OVA_TEMPLATE_NAME}"
    return 1
  fi
}

# downloadAndConcatenate downloads an ova from a url. If the url is split in parts, multiple urls should be given in the right order.
# It also tries to get the sha256 checksum from the same url.
# It assumes multi-part urls are named `*.ova-part-[a-z]+` and the sha256 sum file is named `.*.ova.sha256`
function downloadAndConcatenate() {
    NAME="$(echo "${1}" | tr '/' ' ' | awk '{print $NF}' | sed 's/\.ova.*/\.ova/')"
    SHA256SUM="$(curl -L -s "$(echo "${1}" | awk '{print $1}' | sed -E -e 's/\.ova(|-part-[a-z]+).*/.ova.sha256/')")"
    # shellcheck disable=SC2068
    for dl in ${@}; do
        echo "Downloading ${NAME} via $dl"
        curl -L "$dl" >> "${NAME}"
    done
    echo "${SHA256SUM} ${NAME}" | sha256sum --check --status || echo "ERROR: sha256sum for ${NAME} is invalid!"
}

# importOVA imports an ova to vCenter as template (including a snapshot for linked clones) and to the content library
function importOVA() {
  OVA_PATH="$1"
  OVA_NAME=${OVA_PATH##*/}
  OVA_TEMPLATE_NAME=${OVA_NAME%.ova}

  echo "Importing ${OVA_NAME} from ${OVA_PATH}"

  govc import.spec "${OVA_PATH}"  | jq '.NetworkMapping[] |= (.Network="'$VCENTER_NETWORK_NAME'")' > ova_spec.json
  echo "# uploading OVA to VM"
  govc import.ova "-name=${OVA_TEMPLATE_NAME}" -options=ova_spec.json "${OVA_PATH}"
  echo "# Creating a snapshot for linked clone"
  govc snapshot.create -vm "${OVA_TEMPLATE_NAME}" for-linkedclone
  echo "# Marking as VM as Template"
  govc vm.markastemplate "${OVA_TEMPLATE_NAME}"
  echo "# Import OVA to content library /capv"
  govc library.import /capv "${OVA_PATH}"
}

if [ $# -lt 1 ]; then
  echo "ERROR: Expecting url(s) to an OVA as arguments."
  echo "Example usage:"
  echo "  ${0} https://url-to.ova"
  echo "  ${0} https://url-to.ova-part-aa https://url-to.ova-part-ab"
  exit 1
fi

OVA_PATH="$(echo "${1}" | tr '/' ' ' | awk '{print $NF}' | sed 's/\.ova.*/\.ova/')"
OVA_NAME=${OVA_PATH##*/}
OVA_TEMPLATE_NAME=${OVA_NAME%.ova}

checkIfExists "${OVA_TEMPLATE_NAME}" || exit 1
# shellcheck disable=SC2068
downloadAndConcatenate $@
importOVA "${OVA_PATH}"
