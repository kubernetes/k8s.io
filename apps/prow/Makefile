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

SHELL := /usr/bin/env bash

# These are the usual GKE variables.
PROJECT	?= kubernetes-public
REGION	?= us-central1
CLUSTER	?= aaa
NAMESPACE ?=prow

get-cluster-credentials:
	gcloud container clusters get-credentials "$(CLUSTER)" --project="$(PROJECT)" --region="$(REGION)"

update-config: get-cluster-credentials
	kubectl -n "$(NAMESPACE)" create configmap config --from-file=config.yaml=config.yaml --dry-run=client -o yaml | kubectl replace configmap config -f -

update-plugins: get-cluster-credentials
	kubectl -n "$(NAMESPACE)" create configmap plugins --from-file=plugins.yaml=plugins.yaml --dry-run=client -o yaml | kubectl replace configmap plugins -f -

update-prowjobs: get-cluster-credentials
	kubectl -n "$(NAMESPACE)" create configmap job-config --from-file=$(PWD)/prowjobs/kubernetes/k8s.io/ --dry-run=client -o yaml | kubectl replace configmap job-config -f -
