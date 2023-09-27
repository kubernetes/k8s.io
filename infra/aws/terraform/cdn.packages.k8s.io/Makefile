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
WORKSPACE_NAME ?= canary

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

.PHONY: select
select: ## Select Terraform workspace.
	$(TF) workspace select $(WORKSPACE_NAME)

.PHONY: init
init: ## Initialize Terraform's state and download necessary providers.
	$(TF) $@

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
plan: init ## Present plan for creating/updating Terraform resources.
	$(TF) $@ $(TF_ARGS) \
		-out=plan.out \
		-lock-timeout=$(TF_LOCK_TIMEOUT) \
		-var-file=./terraform.tfvars

.PHONY: apply
apply: ## Create/Update Terraform resources.
	$(TF) $@ $(TF_ARGS) \
		-lock-timeout=$(TF_LOCK_TIMEOUT) \
		"plan.out"
	rm -f plan.out

.PHONY: destroy
destroy: init ## Delete Terraform resources.
	[ $(shell $(TF) workspace show) = "canary" ]
	$(TF) $@ $(TF_ARGS) \
		-lock-timeout=$(TF_LOCK_TIMEOUT) \
		-var-file=./terraform.tfvars

.PHONY: fmt
fmt: ## Format Terraform files.
	$(TF) $@

.PHONY: output
output: init ## Print Terraform output.
	@$(TF) $@ -json

.PHONY: clean
clean: ## Clean up Terraform cache and local state.
	rm -rf ./.terraform ./plan.out
