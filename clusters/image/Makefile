REGISTRY?=quay.io/cblecker
IMAGE=k8s-tf-runner
TAG=$(shell cat VERSION)
# RUNARGS=-v "${PWD}:/tf-project" -v "${HOME}/.terraformrc:/.terraformrc:ro" -v "${HOME}/.config/gcloud/application_default_credentials.json:/credentials.json:ro"
WHAT=plan

default: run

.PHONY: build
build:
	docker build --pull -t $(REGISTRY)/$(IMAGE):$(TAG) .

.PHONY: push
push: build
	docker push $(REGISTRY)/$(IMAGE):$(TAG) $(REGISTRY)/$(IMAGE):latest
#
# .PHONY: run
# run:
# 	docker run $(RUNARGS) $(REGISTRY)/$(IMAGE):$(TAG) $(WHAT)
#
# .PHONY: run-interactive
# run-interactive:
# 	docker run -it --rm -e TF_INPUT=1 $(RUNARGS) $(REGISTRY)/$(IMAGE):$(TAG) $(WHAT)
