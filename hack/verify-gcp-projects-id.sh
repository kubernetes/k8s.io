#!/usr/bin/env bash

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

# Usage: `verify-gcp-project-name.sh`

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd )"
TMPDIR="${TMPDIR:-${REPO_ROOT}/tmp}"

GCP_INFRA_YAML="${REPO_ROOT}/infra/gcp/infra.yaml"
LIST_OF_GCP_PROJECTS="${TMPDIR}/list_of_gcp_projects.txt"
VERIFIED_PROJECTS="${TMPDIR}/verified_project_list.txt"
mkdir -p "$(dirname "${LIST_OF_GCP_PROJECTS}")"
mkdir -p "$(dirname "${VERIFIED_PROJECTS}")"

code=0

number_of_projects=$(yq '.infra | keys | length' "${GCP_INFRA_YAML}")
loop_index_length=$(( number_of_projects - 1 ))

 for index in $(seq 0 $loop_index_length);
 do
	 project=$(yq ".infra | keys | .[${index}]" "${GCP_INFRA_YAML}")
	 yq ".infra.${project}.projects | keys | .[]" "${GCP_INFRA_YAML}" >> "${LIST_OF_GCP_PROJECTS}"
	 yq ".infra.${project}.projects | keys | .[] | match(\"^[a-z][a-z0-9-]{5,28}[^-]$\").string" "${GCP_INFRA_YAML}" >> "${VERIFIED_PROJECTS}"
done


if diff "${LIST_OF_GCP_PROJECTS}" "${VERIFIED_PROJECTS}"
then
	echo '[INFO] All Project ids comply with the GCP project id naming requirements.'
else
	echo -e "[ERROR] The following projects do not fulfill the naming requirements for GCP Project ID. Please refer to the required guidelines here: https://cloud.google.com/resource-manager/docs/creating-managing-projects\n"
	join --nocheck-order -v1 -v2 "${LIST_OF_GCP_PROJECTS}" "${VERIFIED_PROJECTS}"
	code=1
fi

exit "${code}"
