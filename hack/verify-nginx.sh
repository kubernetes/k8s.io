#!/usr/bin/env bash

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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGMAP_FILE="${SCRIPT_DIR}/../apps/k8s-io/configmap-nginx.yaml"
TEMP_DIR=$(mktemp -d)
NGINX_CONF="${TEMP_DIR}/nginx.conf"

cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

echo "Extracting nginx.conf from ConfigMap..."

# Extract the nginx.conf section from the ConfigMap YAML
awk '
/^  nginx\.conf: \|/ {
    # Found the start, skip this line and start collecting
    found = 1
    next
}
found && /^    / {
    # Line starts with 4 spaces (indented content), remove the leading 4 spaces and print
    print substr($0, 5)
    next
}
found && !/^    / && !/^[[:space:]]*$/ {
    # Hit a non-indented line that is not empty, stop collecting
    exit
}
' "${CONFIGMAP_FILE}" > "${NGINX_CONF}"

echo "Extracted nginx.conf to: ${NGINX_CONF}"
echo "Config file size: $(wc -l < "${NGINX_CONF}") lines"

echo "Validating nginx configuration..."

# Check if we can use Docker for validation
if command -v docker >/dev/null 2>&1; then
    # Use the same nginx version as specified in the deployment
    NGINX_IMAGE="nginx:1.26-alpine@sha256:5b44a5ab8ab467854f2bf7b835a32f850f32eb414b749fbf7ed506b139cd8d6b"
    docker run --rm \
        -v "${TEMP_DIR}:/etc/nginx:ro" \
        "${NGINX_IMAGE}" \
        nginx -c /etc/nginx/nginx.conf -t
else
    # Check if nginx is already installed
    if ! command -v nginx >/dev/null 2>&1; then
        if apt-get update -qq && apt-get install -y -qq nginx; then
            echo "Installed nginx via apt"
        fi
    fi
    nginx -c "${NGINX_CONF}" -t
fi

echo "✅ Nginx configuration validation completed successfully!"
