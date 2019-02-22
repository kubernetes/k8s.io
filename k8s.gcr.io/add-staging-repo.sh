#!/bin/sh
#
# This script is used to create a new "staging" repo in GCR.  Each sub-project
# that needs to publish container images should have their own staging repo.
#
# Each staging repo exists in its own GCP project, and is writable by a
# dedicated googlegroup.

set -o errexit
set -o nounset
set -o pipefail

function usage() {
    echo "usage: $0 <repo>" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 coredns" > /dev/stderr
    echo > /dev/stderr
}

function _color() {
    tput setf $1
}

function _nocolor() {
    tput sgr0
}

function color() {
    _color $1
    shift
    echo "$@"
    _nocolor
}

if [ $# != 1 ]; then
    usage
    exit 1
fi
if [ -z "$1" ]; then
    usage
    exit 2
fi

# The name of the sub-project being created, e.g. "coredns".
REPO="$1"

# The GCP project name.
PROJECT="k8s-staging-${REPO}"

# The GCS bucket that backs the GCR repo.
BUCKET="artifacts.${PROJECT}.appspot.com"

# The group that is admins all staging repos.
ADMINS="k8s-infra-gcr-admins@googlegroups.com"

# The group that can write to this staging repo.
WRITERS="k8s-infra-gcr-staging-${REPO}@googlegroups.com"

# The GCP org stuff needed to turn it all on.
ORG="758905017065" # kubernetes.io
BILLING="018801-93540E-22A20E"


# Make the project, if needed
if ! gcloud projects describe "${PROJECT}" >/dev/null 2>&1; then
    color 6 "Creating project ${PROJECT}"
    gcloud projects create "${PROJECT}" \
        --organization "${ORG}"
else
    o=$(gcloud projects \
            describe k8s-staging-coredns \
            --flatten='parent[]' \
            --format='csv[no-heading](type, id)' \
            | grep ^organization \
            | cut -f2 -d,)
    if [ "$o" != "${ORG}" ]; then
        echo "project ${PROJECT} exists, but not in our org: got ${o}"
        exit 2
    fi
fi

color 6 "Configuring billing for ${PROJECT}"
gcloud beta billing projects link "${PROJECT}" \
    --billing-account "${BILLING}"

# Grant project viewer so the UI will work.
color 6 "Granting project viewer to ${ADMINS}"
gcloud \
    projects add-iam-policy-binding "${PROJECT}" \
    --member "group:${ADMINS}" \
    --role roles/viewer

# Enable container registry API
color 6 "Enabling the container registry API"
gcloud --project "${PROJECT}" \
    services enable containerregistry.googleapis.com

# Push an image to trigger the bucket to be created
color 6 "Activating the registry bucket"
PHONY="ceci-nest-pas-une-image"
docker pull k8s.gcr.io/pause
docker tag k8s.gcr.io/pause "gcr.io/${PROJECT}/${PHONY}"
docker push "gcr.io/${PROJECT}/${PHONY}"
gcloud --project "${PROJECT}" \
    container images delete --quiet "gcr.io/${PROJECT}/${PHONY}:latest"

# Grant cross-repo admins access to admin.
color 6 "Granting bucket objectAdmin to ${ADMINS}"
gsutil iam ch "group:${ADMINS}:objectAdmin" "gs://${BUCKET}"
color 6 "Granting bucket legacyBucketOwner to ${ADMINS}"
gsutil iam ch "group:${ADMINS}:legacyBucketOwner" "gs://${BUCKET}"

# Make the bucket publicly readable.
color 6 "Making the bucket public"
gsutil iam ch allUsers:objectViewer "gs://${BUCKET}"

# Grant repo writers access to write.
color 6 "Granting bucket objectAdmin to ${WRITERS}"
gsutil iam ch "group:${WRITERS}:objectAdmin" "gs://${BUCKET}"
color 6 "Granting bucket legacyBucketReader to ${WRITERS}"
gsutil iam ch "group:${WRITERS}:legacyBucketReader" "gs://${BUCKET}"

# Set lifecycle policies.
color 6 "Setting lifecycle to age-out old data"
echo '
    {
      "rule": [
        {
          "condition": {
            "age": 30
          },
          "action": {
            "storageClass": "NEARLINE",
            "type": "SetStorageClass"
          }
        },
        {
          "condition": {
            "age": 90
          },
          "action": {
            "type": "Delete"
          }
        }
      ]
    }
    ' | gsutil lifecycle set /dev/stdin "gs://${BUCKET}"

color 6 "Done"
