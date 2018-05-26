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

FROM golang:1.10.1-alpine

LABEL maintainer="Davanum Srinivas <davanum@gmail.com>"

COPY config.json /data/config.json

ENV GOPATH /go

RUN apk add --no-cache git make \
    && go get -d github.com/etsy/hound/cmds/...
RUN cd /go/src/github.com/etsy/hound \
    && git checkout 1b9c3e53594f7eded11fc259537c443853db4587 \
    && go install github.com/etsy/hound/cmds/houndd \
    && rm -rf /go/src /go/pkg

VOLUME ["/data"]

EXPOSE 8080

ENTRYPOINT ["/go/bin/houndd", "-conf", "/data/config.json", "-addr", ":8080"]
