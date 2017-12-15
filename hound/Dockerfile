# Copyright 2017 The Kubernetes Authors.
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

FROM debian
LABEL maintainer="Davanum Srinivas <davanum@gmail.com>"

COPY config.json /data/config.json

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    golang-go \
    ca-certificates \
    git \
    && apt-get clean

ENV GOPATH /go

RUN go get github.com/etsy/hound/cmds/...

VOLUME ["/data"]

EXPOSE 6080

ENTRYPOINT ["/go/bin/houndd", "-conf", "/data/config.json"]