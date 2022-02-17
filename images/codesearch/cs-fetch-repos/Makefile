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
IMAGE ?= cs-fetch-repos
REPO ?= gcr.io/k8s-staging-infra-tools
TAG_DATE_SHA ?= v$(shell date -u '+%Y%m%d')-$(shell git describe --tags --always --dirty)
TAG ?= $(TAG_DATE_SHA)

# run
WHAT ?= python ./fetch-repos.py

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

run:
	docker run \
		--rm \
		$(image_spec) \
		$(WHAT)

cloudbuild:
	gcloud builds submit \
		--verbosity info \
		--config cloudbuild.yaml \
		--substitutions _TAG=$(TAG_DATE_SHA),_GIT_TAG=$(TAG_DATE_SHA) \
		--project $(PROJECT_ID) \
		--gcs-source-staging-dir $(GCB_BUCKET)/source \
		.
