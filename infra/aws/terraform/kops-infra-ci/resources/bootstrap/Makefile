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

AWS_ECR_ACCOUNT_ID ?= 808842816990
AWS_ECR_REGION ?= us-east-2
 # Keep that in sync with the terraform resource aws_ecr_repository.repo
AWS_ECR_REPO ?= eks-bootstrap
AWS_ECR_URI ?= $(AWS_ECR_ACCOUNT_ID).dkr.ecr.$(AWS_ECR_REGION).amazonaws.com
TAG ?= v0.0.1

ecr-login:
	aws ecr get-login-password --region $(AWS_ECR_REGION) --profile kops-ci | docker login --username AWS --password-stdin $(AWS_ECR_URI)

docker-build:
	docker build --platform linux/amd64 -t $(AWS_ECR_REPO):$(TAG) -f Dockerfile .

push: docker-build ecr-login
	docker tag $(AWS_ECR_REPO):$(TAG) $(AWS_ECR_URI)/$(AWS_ECR_REPO):$(TAG)
	docker push $(AWS_ECR_URI)/$(AWS_ECR_REPO):$(TAG)
