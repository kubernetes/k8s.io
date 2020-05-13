# Copyright 2019 The Kubernetes Authors.
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

SHELL := /usr/bin/env bash
CANARY_ZONES := canary.k8s.io. canary.kubernetes.io. canary.x-k8s.io. canary.k8s-e2e.com.
PROD_ZONES := k8s.io. kubernetes.io. x-k8s.io. canary.k8s-e2e.com.
ZONE_CONFIGS := zone-configs
DOCKER_IMAGE ?= us.gcr.io/k8s-artifacts-prod/infra-tools/octodns:latest

default: check

.PHONY: check
check: check-canary check-prod

.PHONY: check-canary
check-canary:
	$(CURDIR)/check-zone.sh -c $(ZONE_CONFIGS) $(CANARY_ZONES)

.PHONY: check-prod
check-prod:
	$(CURDIR)/check-zone.sh -c $(ZONE_CONFIGS) $(PROD_ZONES)

.PHONY: dry-run
dry-run:
	docker run -ti \
		--user $(shell id -u) \
		--volume ~/.config/gcloud:/.config/gcloud:ro \
		--volume $(CURDIR):/octodns:ro \
		--workdir /octodns \
		$(DOCKER_IMAGE) \
		./push.sh \
			--check-zone-script ./octodns-docker/check-zone.py \
			--logs-dir /tmp \
			--octodns-config ./octodns-config.yaml \
			--zone-configs $(ZONE_CONFIGS) \
			$(ARGS)

.PHONY: push
push: ARGS := --confirm
push: dry-run

.PHONY: build
build:
	docker build -t $(USER)/octodns $(CURDIR)/octodns-docker

.PHONY: dry-run-local
dry-run-local:
	$(CURDIR)/push.sh \
		--check-zone-script ./octodns-docker/check-zone.py \
		--octodns-config ./octodns-config.yaml \
		--zone-configs $(ZONE_CONFIGS) \
		$(ARGS)

.PHONY: push-local
push-local: ARGS := --confirm
push-local: dry-run-local
