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


# Adds a new component version for promotion.
# Can also be used to verify if an already-added version is OK, should produce
# empty diff in such a case.
# NOTE: Only modifies local files, does not create a PR.

if [ "$2". == . ] || [ "$3". != . ]
then
  echo "Usage: $0 <component name> <version tag>"
  echo "example usages:"
  echo "    $0 addon-resizer 1.8.16"
  echo "    $0 vpa-updater 0.14.1"
  echo "    $0 vpa 0.14.1            # to update all VPA components"
  exit 1
fi

COMPONENT="$1"
VERSION="$2"

component_len=${#COMPONENT}
should_read=1

function emit_new_sha {
  sha=$(gcloud container images describe "gcr.io/k8s-staging-autoscaling/${component}:${VERSION}" '--format=value(image_summary.digest)' 2>/dev/null)
  echo "    \"${sha}\": [\"${VERSION}\"]"
}

function handle_component {
  # consume 'dmap' line, w/o checking contents
  read -r || exit 1
  echo "$REPLY"

  replaced=0
  # consume all sha256 lines, with content checks
  while true
  do
    read -r || break
    is_sha=$(echo "$REPLY" | grep -c 'sha256:')
    if [ "$is_sha" == 1 ]
    then
      # sha256 line, check if we need to overwrite or simply copy
      same_version=$(echo "$REPLY" | grep -c "\[\"${VERSION}\"\]")
      if [ "$same_version" == 1 ]
      then
        echo "WARNING: replacing existing entry for ${component} ${VERSION}" >&2
        emit_new_sha
        replaced=1
      else
        echo "$REPLY"
      fi
    else
      # non-sha256, assuming end of section of sha256
      # add the new version and emit the already-consumed line so it's not lost
      if [ "$replaced" == 0 ]
      then
        emit_new_sha
      fi
      echo "$REPLY"
      return
    fi
  done

  # EOF, we only add the new version
  if [ "$replaced" == 0 ]
  then
    emit_new_sha
  fi
}

while true
do
  if [ "$should_read" -gt 0 ]
  then
    read -r || break
    echo "$REPLY"
  fi
  should_read=1

  if [ "${REPLY:0:8}" == "- name: " ]
  then
    component=${REPLY:8}
    if [ "${component:0:$component_len}" == "${COMPONENT}" ]
    then
      handle_component
      # we need to process the final line read by handle_component
      should_read=0
    fi
  fi

done <images.yaml >images.yaml.new

mv images.yaml.new images.yaml

echo 'DONE, please have a look at diff output below and create PR if it looks OK'
echo
git diff images.yaml
echo
echo 'See ya'
