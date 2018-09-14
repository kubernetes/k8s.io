#!/bin/bash

. ./env

REPO=${DNS_SYNC_REPO:-${USER}}
IMAGE=${DNS_SYNC_IMAGE:-octodns}
VERSION=${DNS_SYNC_VERSION:-$(git describe --always --dirty)}

echo "Building ${REPO}/${IMAGE}:${VERSION}"

docker build -t ${REPO}/${IMAGE}:${VERSION} .