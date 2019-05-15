#!/bin/bash
set -x -e
CNCF_GCP_ORG=758905017065

# gcloud organizations describe $CNCF_GCP_ORG 2>&1
# ERROR: (gcloud.organizations.describe)
# User [hh@ii.coop] does not have permission to access organization []

for format in json yaml
do
    gcloud iam roles list --organization=$CNCF_GCP_ORG --format=$format \
           > cncf-org.roles.$format
    gcloud organizations get-iam-policy $CNCF_GCP_ORG --format=$format \
           > cncf-org.policy.$format
    gcloud projects list \
           --filter "parent.id=$CNCF_GCP_ORG" \
           --format "value(name, projectNumber)" \
        | while read NAME NUM; do \
        gcloud projects get-iam-policy $NAME --format=$format > $NAME.policy.$format
        gcloud iam roles list --project=$NAME --format=$format > $NAME.roles.$format
        mkdir -p roles
        for ROLE_PATH in `gcloud --project=$NAME iam roles list --format="value(name)"`
        do
            ROLE=`basename $ROLE_PATH`
            gcloud --project=$NAME iam roles describe $ROLE \
                   --format=json > roles/$ROLE.json
        done

    done
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
