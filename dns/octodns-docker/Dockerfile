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

# python:3-alpine as of December 14th, 2025
ARG BASE_IMAGE=python@sha256:2a77c2640cc80f5506babd027c883abc55f04d44173fd52eeacea9d3b978e811
FROM ${BASE_IMAGE}

RUN apk add \
        bash=5.3.3-r1 \
        make=4.4.1-r3

# install from requirements.txt and ensure that all requirements match
# pip freeze after, guaranteeing that we will install the same packages if we
# build again
COPY requirements.txt /requirements.txt
RUN pip install -r /requirements.txt && \
    echo "freezing deps, please make sure requirements.txt matches" && \
    pip freeze | tee /newrequirements.txt && \
    diff /requirements.txt /newrequirements.txt
# To enable debugging:
# RUN pip install ipython ipdb
# pair with the following at breakpoints in python code:
# import ipdb ; ipdb.set_trace()

ADD https://github.com/mikefarah/yq/releases/download/v4.20.2/yq_linux_amd64 /usr/local/bin/yq
RUN chmod +x /usr/local/bin/yq

CMD /bin/sh
