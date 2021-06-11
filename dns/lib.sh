#!/usr/bin/env bash

# Copyright 2020 The Kubernetes Authors.
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

# Some zones have multiple files that need to be joined
# Args:
#   $1: path where processed zone configs will be placed
#   $2,...: zones which configs to precook
precook_zone_configs() {
    if (( $# < 2)); then
        echo -n "precook_zone_configs(path, ...zone): function" >&2 
        echo    " expects at least 2 arguments" >&2
        exit 1
    fi

    local path="${1}"; shift
    local zones=("$@")

    for z in "${zones[@]}"; do
        # Every zone should have 1 file $z.yaml or N files $z._*.yaml.
        # $z already ends in a period.
        cat "zone-configs/${z}"yaml "zone-configs/${z}"_*.yaml \
            > "${path}/${z}yaml" 2>/dev/null
        if [ ! -s "${path}/${z}yaml" ]; then
            echo "${path}/${z}yaml appears to be empty after pre-processing!"
            exit 1
        fi
    done
}

# Change providers.config.directory in octodns config file to the directory
# of processed zone-configs as it's the place where processed zone configs
# will be held
# Args:
#   $1: path to octodns-config.yaml file which will be used as a template
#   $2: path to processed (precooked) zone config files
#   $3: path where to put processed octodns config file
precook_octodns_config() {
    if (( $# != 3)); then
        echo -n "precook_octodns_config(input_config_path," >&2 
        echo -n " zone_configs_path, output_config_path): function" >&2 
        echo    " expects 3 arguments" >&2
        exit 1
    fi

    local input_config_path="${1}"
    local zone_configs_path="${2}"
    local output_config_path="${3}"

    sed "s|directory:.*$|directory: ${zone_configs_path}|" \
        < "${input_config_path}" \
        > "${output_config_path}"
}
