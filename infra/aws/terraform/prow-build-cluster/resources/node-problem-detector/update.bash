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

#!/usr/bin/env bash
set -xeuo pipefail

dir="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

tag=7fc7947bc3f83b70ea6614e04db4cd2aebe7ef87
repo=https://raw.githubusercontent.com/kubernetes/node-problem-detector
files=( node-problem-detector.yaml rbac.yaml )
# NOTE: the config is heavily modified, pulling it from upstream requires
# manual work to ensure it contains necessary content
#files+=( node-problem-detector-config.yaml )
for f in "${files[@]}"; do
    echo $f
    wget "${repo}/${tag}/deployment/${f}" -O "${dir}/${f}"
done

function boilerplate() {
  cat ${dir}/../../../../../../hack/boilerplate/boilerplate.sh.txt | sed -e "s/\<YEAR\>/$(date +'%Y')/"
}

for f in "${files[@]}"; do 
    cat <(boilerplate) "${dir}/${f}" > tmp.yaml
    mv tmp.yaml "${dir}/${f}"
done
