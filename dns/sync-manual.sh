#!/bin/bash

script_root=$(dirname $(readlink -f {BASH_SOURCE}))

. ${script_root}/env

REPO=${DNS_SYNC_REPO:-${USER}}
IMAGE=${DNS_SYNC_IMAGE:-octodns}
VERSION=${DNS_SYNC_VERSION:-$(git describe --always --dirty)}

doit="--doit"

while getopts ":dh" opt; do
  case $opt in
    d)
      echo "Dry run specified, skipping synchronizing"
      doit=""
      ;;
    h | \?)
      echo "Usage: ${0} [-d]"
      echo "  -d: Dry run, skip actual synchronization" >&2
      exit 1
      ;;
  esac
done

docker run -ti \
    -u `id -u` \
    -v ~/.config/gcloud:/.config/gcloud:ro \
    -v ${script_root}/config:/octodns/config:ro \
    -v ${script_root}/config.yaml:/octodns/config.yaml:ro \
    myname/octodns \
    octodns-sync \
        --config-file=/octodns/config.yaml \
        --log-stream-stdout \
        --debug \
        ${doit} 

