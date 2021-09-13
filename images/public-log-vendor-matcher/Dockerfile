FROM golang:1.16.5-stretch AS godeps
RUN go get -u github.com/mikefarah/yq/v4 && \
  test -f /go/bin/yq

FROM postgres:12.7 AS final
LABEL maintainer "ii <public-log-vendor-matcher@ii.coop>"
RUN apt-get update && \
  apt-get install -y curl && \
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
    | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - && \
  apt-get update && \
  apt-get install  -y --no-install-recommends \
  python3 \
  python3-dev \
  python3-pip \
  python3-wheel \
  python3-setuptools \
  jq \
  curl \
  git \
  gcc \
  libc6-dev \
  gettext-base \
  procps \
  google-cloud-sdk && \
  rm -rf /var/lib/apt/lists/*
RUN pip3 install pyasn
WORKDIR /app
COPY --from=godeps /go/bin/yq /usr/local/bin/yq
COPY ./pg-init.d /docker-entrypoint-initdb.d
COPY ./app .
ENV POSTGRES_PASSWORD=postgres
