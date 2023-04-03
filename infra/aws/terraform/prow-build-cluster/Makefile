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
ASSUME_ROLE ?= true

# Valid values are: canary, prod
WORKSPACE_NAME ?= canary

.PHONY: workspace-select
workspace-select:
	$(TF) workspace select $(WORKSPACE_NAME)

.PHONY: init
init:
	$(TF) $@

.PHONY: plan
plan: workspace-select
	$(TF) $@ \
		-var="assume_role=$(ASSUME_ROLE)" \
		-var-file=./terraform.$(WORKSPACE_NAME).tfvars

.PHONY: apply
apply: workspace-select
	$(TF) $@ \
		-var="assume_role=$(ASSUME_ROLE)" \
		-var-file=./terraform.$(WORKSPACE_NAME).tfvars

.PHONY: destroy
destory: workspace-select
	$(TF) $@ \
		-var="assume_role=$(ASSUME_ROLE)" \
		-var-file=./terraform.$(WORKSPACE_NAME).tfvars

.PHONY: fmt
fmt:
	$(TF) $@

.PHONY: output
output:
	$(TF) $@

.PHONY: clean
clean:
	rm -rf ./.terraform

