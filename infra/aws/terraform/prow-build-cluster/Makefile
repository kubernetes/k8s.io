TF ?= terraform
ASSUME_ROLE ?= true

# Valid values are: canary, prod
PROW_CLUSTER ?= canary

.PHONY: init
init:
	$(TF) init \
		-backend-config=./tfbackends/$(PROW_CLUSTER).tfbackend

.PHONY: plan
plan:
	$(TF) plan \
		-var-file=./terraform.$(PROW_CLUSTER).tfvars \
		-var="assume_role=$(ASSUME_ROLE)"

.PHONY: apply
apply:
	$(TF) apply \
		-var-file=./terraform.$(PROW_CLUSTER).tfvars \
		-var="assume_role=$(ASSUME_ROLE)"

.PHONY: destroy
destory:
	$(TF) destroy \
		-var-file=./terraform.$(PROW_CLUSTER).tfvars \
		-var="assume_role=$(ASSUME_ROLE)"

.PHONY: clean
clean:
	rm -rf ./.terraform
