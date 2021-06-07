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

## user-facing variables
# build run
IMAGE ?= k8s-infra
REPO ?= gcr.io/k8s-staging-infra-tools
TAG_DATE_SHA ?= v$(shell date -u '+%Y%m%d')-$(shell git describe --tags --always --dirty)
TAG ?= $(TAG_DATE_SHA)

# run
WHAT ?= /bin/bash
# cloudbuild
PROJECT_ID ?= k8s-staging-infra-tools
GCB_BUCKET ?= gs://$(PROJECT_ID)

## user-facing targets
.PHONY: build run cloudbuild

## variables

# allow bash-isms to be used in $(shell foo)
SHELL := /usr/bin/env bash
makefile_root := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
repo_root := $(abspath $(makefile_root)/../..)
image_spec := $(REPO)/$(IMAGE):$(TAG)

## targets

build:
	docker build \
		--file Dockerfile \
		--tag $(image_spec) \
		--tag $(REPO)/$(IMAGE):$(TAG_DATE_SHA) \
		.

# includes env vars known to be consumed by k8s-infra scripts:
# - audit/audit-gcp.sh
# - infra/gcp/lib.sh
# - infra/gcp/lib_services.sh (via infra/gcp/ensure-*.sh)
# - infra/gcp/prow/ensure-e2e-projects.sh
run:
	docker run \
		--rm --interactive \
		--tty \
		--volume $(HOME)/.config/gcloud:/root/.config/gcloud \
		--volume $(HOME)/.gitconfig:/root/.gitconfig \
		--volume $(HOME)/.secrets/github.token:/etc/github-token/token \
		--volume $(repo_root):/workspace/kubernetes/k8s.io \
		--workdir /workspace/kubernetes/k8s.io \
		--env K8S_INFRA_AUDIT_SERVICES \
		--env K8S_INFRA_DEBUG \
		--env K8S_INFRA_ENSURE_E2E_PROJECTS_RESETS_SSH_KEYS \
		--env K8S_INFRA_ENSURE_ONLY_SERVICES_WILL_FORCE_DISABLE \
		$(image_spec) \
		$(WHAT)

# an approximation of what kubernetes/test-infra/images/builder calls,
# with TAG overriden to prevent accidental manual pushes to :latest
cloudbuild:
	gcloud builds submit \
		--verbosity info \
		--config cloudbuild.yaml \
		--substitutions _TAG=$(TAG_DATE_SHA),_GIT_TAG=$(TAG_DATE_SHA) \
		--project $(PROJECT_ID) \
		--gcs-source-staging-dir $(GCB_BUCKET)/source \
		.
