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

# https://hub.docker.com/_/alpine
# 3.18 as of 12/07/2023
FROM alpine@sha256:34871e7290500828b39e22294660bee86d966bc0017544e848dd9a255cdf59e0

RUN apk update \
    && apk add --no-cache \
        bash \
        findutils \
        util-linux \
        xfsprogs

ADD https://raw.githubusercontent.com/kubernetes/k8s.io/a8be6bcc88c61dc55ce0f6b888e7f4e6c0a5293d/infra/aws/terraform/prow-build-cluster/bootstrap_bottlerocket/node_bootstrap.sh /bootstrap.sh

RUN chmod +x /bootstrap.sh

ENTRYPOINT ["bash", "/bootstrap.sh"]
