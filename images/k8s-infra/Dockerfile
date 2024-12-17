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

# Intended to hold all dependencies needed to build, test and run all tools
# used by sig-k8s-infra. With sufficient credentials mounted in, should be
# capable of running those tools to test and deploy all kubernetes project
# infrastructure managed by sig-k8s-infra.

# base image
FROM debian:bookworm

# build args

# unless otherwise stated, versions were arbitrarily chosen to whatever was
# latest at the time, and package-based installs from debian-maintained repos
# are not pinned to a specific version

ARG CONFTEST_VERSION=0.54.0
ARG GCLOUD_VERSION=467.0.0
ARG GH_VERSION=2.63.2
ARG GO_VERSION=1.23.4
ARG JQ_VERSION=1.6
# K8S_VERSION should be within +/- 1 minor version of our clusters
# ref: https://kubernetes.io/releases/version-skew-policy/#kubectl
ARG K8S_VERSION=1.30.8
ARG OPA_VERSION=0.70.0
ARG SHELLCHECK_VERSION=0.9.0
ARG TFSWITCH_VERSION=1.2.4
ARG RCLONE_VERSION=1.68.2

# build everything in /build
WORKDIR /build

# multiple ENV assignments in one layer
# - put $(go env GOROOT)/bin on PATH
# - disable interactive prompts for gcloud commands (use defaults, or error if unable)
# - enable usage of the gke auth plugin for gcloud
ENV PATH=/usr/local/go/bin:${PATH} \
    CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
    USE_GKE_GCLOUD_AUTH_PLUGIN=True

# used to pip install: awscli, yamllint, yq
COPY requirements.txt .

# use bash for pipefail and pushd/popd
SHELL ["/bin/bash", "-c"]
RUN set -o errexit nounset pipefail \
    && echo "Installing Packages ..." \
        && apt-get update \
        && apt-get install -y --no-install-recommends \
            curl \
            gcc \
            git \
            gnupg2 \
	    groff \
            make \
            libc6-dev \
            python3 \
            python3-pip \
            xz-utils \
    && echo "Installing python tools ..." \
        && pip3 install --requirement requirements.txt --break-system-packages --no-build-isolation \
    && echo "Installing go ..." \
        && export GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz" \
        && curl -fsSL "https://golang.org/dl/${GO_TARBALL}" --output tarball.tar.gz \
        && tar xf tarball.tar.gz -C /usr/local \
        && rm tarball.tar.gz \
    && echo "Installing Google Cloud SDK ..." \
        && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
            | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
        && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
        && apt-get update -o Dir::Etc::sourcelist="sources.list.d/google-cloud-sdk.list" \
            -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" \
        && apt-get install -y --no-install-recommends \
            "google-cloud-sdk=${GCLOUD_VERSION}-0" \
            python3-crcmod \
        && gcloud config set core/disable_usage_reporting true \
        && gcloud config set component_manager/disable_update_check true \
        && gcloud config set metrics/environment github_docker_image \
    && echo "Install GKE auth plugin" \
        && apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin \
    && echo "Installing gh ..." \
        && echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | tee -a /etc/apt/sources.list.d/github-cli.list \
        && curl -fsSLo /usr/share/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
        && apt-get update -o Dir::Etc::sourcelist="sources.list.d/github-cli.list" \
            -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" \
        && apt-get install -y --no-install-recommends \
            "gh=${GH_VERSION}" \
    && echo "Installing conftest ..." \
        && export BASE_URL="https://github.com/open-policy-agent/conftest/releases/download" \
        && export URL="${BASE_URL}/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
        && curl -fsSL "${URL}" --output tarball.tar.gz \
        && tar xf tarball.tar.gz -C /usr/local/bin \
        && rm tarball.tar.gz \
    && echo "Installing jq ..." \
        && curl -fsSL "https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64" --output /usr/local/bin/jq \
        && chmod +x /usr/local/bin/jq \
    && echo "Installing kubectl ..." \
        && curl -fsSL "https://dl.k8s.io/release/v${K8S_VERSION}/bin/linux/amd64/kubectl" --output /usr/local/bin/kubectl \
        && chmod +x /usr/local/bin/kubectl \
    && echo "Installing opa ..." \
        && curl -fsSL "https://openpolicyagent.org/downloads/v${OPA_VERSION}/opa_linux_amd64" --output /usr/local/bin/opa \
        && chmod +x /usr/local/bin/opa \
    && echo "Installing rclone ..." \
        && curl -fsSSL "https://downloads.rclone.org/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-amd64.deb" --output /tmp/rclone_amd64.deb \
        && dpkg -i /tmp/rclone_amd64.deb \
        && rm -f /tmp/rclone_amd64.deb \
    && echo "Installing shellcheck ..." \
        && export BASE_URL="https://github.com/koalaman/shellcheck/releases/download" \
        && export URL="${BASE_URL}/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" \
        && curl -fsSL "${URL}" --output tarball.tar.xz \
        && tar xf tarball.tar.xz -C /usr/local/bin --strip-components 1 "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" \
        && rm tarball.tar.xz \
    && echo "Installing tfswitch ..." \
        && export BASE_URL=https://github.com/warrensbox/terraform-switcher/releases/download \
        && export URL="${BASE_URL}/v${TFSWITCH_VERSION}/terraform-switcher_v${TFSWITCH_VERSION}_linux_amd64.tar.gz" \
        && curl -fsSL "${URL}" --output tarball.tar.gz \
        && tar xf tarball.tar.gz -C /usr/local/bin tfswitch \
        && rm tarball.tar.gz \
    && echo "Installing terraform ..." \
        && tfswitch --latest-stable=1.1 \
        && tfswitch --latest-stable=1.2 \
        && tfswitch --latest-stable=1.3 \
    && echo "Installing pr-creator" \
        && git clone --depth 1 https://github.com/kubernetes/test-infra \
        && pushd ./test-infra \
        && go build -o /usr/local/bin/pr-creator ./robots/pr-creator \
        && popd \
    && echo "Outputting version info to confirm installation of expected tools ..." \
        && apt list --installed         | tee apt-list.txt \
	&& aws --version		| tee awscli-version.txt \
        && bq version                   | tee bq-version.txt \
        && conftest --version           | tee conftest-version.txt \
        && curl --version               | tee curl-version.txt \
        && gcloud info                  | tee gcloud-info.txt \
        $$ git --version                | tee git-version.txt \
        && gh --version                 | tee gh-version.txt \
        && go version                   | tee go-version.txt \
        && gsutil --version             | tee gsutil-version.txt \
        && jq --version                 | tee jq-version.txt \
        && kubectl version --client     | tee kubectl-version.txtl \
        && opa version                  | tee opa-version.txt \
        && pr-creator --help            | tee pr-creator-help.txt \
        && git -C test-infra log -n1    | tee pr-creator-version.txt \
        && python3 --version            | tee python-version.txt \
        && rclone version             | tee rclone.txt \
        && shellcheck --version         | tee shellcheck-version.txt \
        && terraform --version          | tee terraform-version.txt \
        && tfswitch --version           | tee tfswitch-version.txt \
        && yamllint --version           | tee yamllint-verison.txt \
        && yq --version                 | tee yq-version.txt \
    && echo "Cleaning up ..." \
        && apt autoremove -y \
        && apt clean -y \
        && rm -rf /var/lib/apt/lists/* \
        && rm -rf /root/.cache \
        && rm -rf /root/go/pkg \
        && rm -rf ./test-infra


# run everything in /workspace
WORKDIR /workspace

CMD /bin/bash
