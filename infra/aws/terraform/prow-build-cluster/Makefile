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

TF ?= terraform
TF_ARGS ?=
TF_LOCK_TIMEOUT ?= 30s

# Valid values are: canary, prod
PROW_ENV ?= canary

KUBECTL ?= kubectl

# TODO: figure out a workaround for: https://github.com/hashicorp/terraform-provider-kubernetes-alpha/issues/199#issuecomment-832614387
DEPLOY_K8S_RESOURCES ?= true

##@ Helpers:

.PHONY: help
help: ## Display this help.
	@awk \
		-v "col=${COLOR}" -v "nocol=${NOCOLOR}" \
		' \
			BEGIN { \
				FS = ":.*##" ; \
				printf "\nUsage:\n  make %s<target>%s\n", col, nocol \
			} \
			/^[a-zA-Z_-]+:.*?##/ { \
				printf "  %s%-15s%s %s\n", col, $$1, nocol, $$2 \
			} \
			/^##@/ { \
				printf "\n%s%s%s\n", col, substr($$0, 5), nocol \
			} \
		' $(MAKEFILE_LIST)

##@ Terraform:

.PHONY: init
init: ## Initialize Terraform's state and download necessary providers.
	$(TF) $@ \
		-backend-config=./tfbackends/$(PROW_ENV).tfbackend

.PHONY: platforms-lock
platforms-lock:
	$(TF) \
		providers lock \
		-platform=linux_arm64 \
		-platform=linux_amd64 \
		-platform=darwin_amd64 \
		-platform=windows_amd64 \
		-platform=darwin_arm64

.PHONY: plan
plan: ## Present plan for creating/updating Terraform resources.
	$(TF) $@ $(TF_ARGS) \
		-out=plan.out \
		-lock-timeout=$(TF_LOCK_TIMEOUT) \
		-var-file=./terraform.tfvars \
		-var-file=./terraform.$(PROW_ENV).tfvars \
		-var="deploy_kubernetes_resources=$(DEPLOY_K8S_RESOURCES)"

.PHONY: apply
apply: ## Create/Update Terraform resources.
	$(TF) $@ $(TF_ARGS) \
		-lock-timeout=$(TF_LOCK_TIMEOUT) \
		"plan.out"
	rm -f plan.out

.PHONY: destroy
destroy: ## Delete Terraform resources.
	[ $(PROW_ENV) = "canary" ]
	$(TF) $@ $(TF_ARGS) \
		-lock-timeout=$(TF_LOCK_TIMEOUT) \
		-var-file=./terraform.tfvars \
		-var-file=./terraform.$(PROW_ENV).tfvars \
		-var="deploy_kubernetes_resources=$(DEPLOY_K8S_RESOURCES)"

.PHONY: fmt
fmt: ## Format Terraform files.
	$(TF) $@

.PHONY: output
output: ## Print Terraform output.
	@$(TF) $@ -json

.PHONY: clean
clean: ## Clean up Terraform cache and local state.
	rm -rf ./.terraform ./plan.out

##@ FluxCD:

.PHONY: flux-install
flux-install: ## Install FluxCD components inside flux-system namespace.
	${KUBECTL} apply --server-side -f ./resources/flux-system/gotk-components.yaml

.PHONY: flux-apply-sources
flux-apply-sources: ## Apply FluxCD Sources located inside "./resources/flux-system" folder.
	find ./resources/flux-system -type f -name "flux-source-*" -exec ${KUBECTL} apply -f {} \;

.PHONY: flux-apply-kustomizations
flux-apply-kustomizations: ## Apply FluxCD Kustomizations located inside "./resources/flux-system" folder.
	find ./resources/flux-system -type f -name "flux-ks-*" -exec ${KUBECTL} apply -f {} \;

.PHONY: flux-apply-helm-releases
flux-apply-helm-releases: ## Apply HelmReleases located inside "./resources" folder.
	find ./resources -type f -name "flux-hr-*" -exec ${KUBECTL} apply -f {} \;

PHONY: flux-apply-all
flux-apply-all: flux-apply-sources flux-apply-kustomizations flux-apply-helm-releases ## Apply FluxCD Sources, Kustomizations and HelmReleases, all at once.

.PHONY: flux-update
flux-update: ## Update FluxCD manifests, generate Kustomizations and HelmReleases (requires flux cli).
	PROW_ENV=$(PROW_ENV) ./hack/flux-update.bash
