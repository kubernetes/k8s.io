#!/bin/bash
set -x -e
CNCF_GCP_ORG=758905017065

# gcloud organizations describe $CNCF_GCP_ORG 2>&1
# ERROR: (gcloud.organizations.describe)
# User [hh@ii.coop] does not have permission to access organization []

for format in json yaml
do
    gcloud organizations get-iam-policy $CNCF_GCP_ORG --format=$format \
           > cncf-org-policy.$format
    gcloud projects get-iam-policy kubernetes-public --format=$format \
           > kubernetes-public-policy.$format
    gcloud iam roles list --organization=758905017065 --format=$format \
           > cncf-org-roles.$format
    gcloud iam roles list --project=kubernetes-public --format=$format \
           > kubernetes-public-roles.$format
done

# Permissions per project role
mkdir -p roles
for ROLE_PATH in `gcloud --project=kubernetes-public iam roles list --format="value(name)"`
do
    ROLE=`basename $ROLE_PATH`
    gcloud --project=kubernetes-public iam roles describe $ROLE \
           --format=json > roles/$ROLE.json
done


# List of objets in buckets
mkdir -p buckets
for BUCKET in `gsutil ls -p kubernetes-public | awk -F/ '{print $3}'`
do
    gsutil ls -r gs://$BUCKET/ > buckets/$BUCKET.txt
done


# TODO:
# Dump iam for each GCS Bucket
# Dump iam for Big Query
# Iterate over enabled APIs per project
# Identify each resource, then dump iam
