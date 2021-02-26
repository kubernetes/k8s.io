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

set -o errexit
set -o nounset
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function usage() {
  echo >&2 "Usage: $0 <CLUSTER_NAME>"
  exit 1
}

function check_terraform() {
  if [ $# != 1 ]; then
    echo "check_terraform(path) requires 1 argument" >&2
    exit 1
  fi

  if [ ! -d "$1" ]; then
    echo "path not found"
    exit 1
  fi

  cd "$1"
  echo "Installing Terraform"
  tfswitch
  echo "Running terraform validate"
  terraform init -backend=false
  terraform validate
}


if [ $# != 1 ]; then
    usage
    exit 1
fi

if [ -z "$(which curl)" ]; then
  echo "Please install curl"
  exit 1
fi


if [ -z "$(which tfswitch)" ]; then
  echo "Installing tfswitch locally"
  curl -L https://raw.githubusercontent.com/warrensbox/terraform-switcher/release/install.sh | sudo bash
else
tfswitch --version
fi

check_terraform "${DIR}/../$1"
