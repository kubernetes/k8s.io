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

## To authenticate, run:
##   aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/q4o2z4d8

REPO ?= public.ecr.aws/q4o2z4d8/k8s-prow-bottlerocket

TAG ?= v0.0.2

docker-build:
	docker build --platform linux/amd64 -t $(REPO):$(TAG) .

docker-push: docker-build
	docker push $(REPO):$(TAG)
