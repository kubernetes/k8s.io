#!/bin/bash
#
# check-zone.sh
#
# $1: "canary" or "prod"

DOMAIN=$1
echo "Checking that the GCP dns servers for $DOMAIN serve up everything in our octodns config"
docker run -ti \
       -u `id -u` \
       -v ~/.config/gcloud:/.config/gcloud:ro \
       -v `pwd`/octodns-config.yaml:/octodns/config.yaml:ro \
       -v `pwd`/zone-configs:/octodns/config:ro \
       ${USER}/octodns \
       check-zone \
       --config-file=/octodns/config.yaml \
       --zone $1
RESULT=$?
if [ $RESULT != "0" ] ; then
    echo '***FAIL***'
    echo $RESULT
    exit $RESULT
else
    echo '***PASS***'
fi
