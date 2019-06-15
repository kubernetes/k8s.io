#!/bin/bash
set -x -e
CNCF_GCP_ORG=758905017065

# gcloud organizations describe $CNCF_GCP_ORG 2>&1
# ERROR: (gcloud.organizations.describe)
# User [hh@ii.coop] does not have permission to access organization []

format=json
gcloud iam roles list --organization=$CNCF_GCP_ORG --format=$format \
       > cncf-org.roles.$format
gcloud organizations get-iam-policy $CNCF_GCP_ORG --format=$format \
       > cncf-org.policy.$format
gcloud projects list \
       --filter "parent.id=$CNCF_GCP_ORG" \
       --format "value(name, projectNumber)" \
    | while read PROJECT NUM; do \
    export CLOUDSDK_CORE_PROJECT=$PROJECT
    gcloud projects get-iam-policy $PROJECT --format=$format > $PROJECT.policy.$format
    gcloud iam roles list --project $PROJECT --format=$format > $PROJECT.roles.$format
    mkdir -p $PROJECT.roles
    for ROLE_PATH in `gcloud iam roles list --project $PROJECT --format="value(name)"`
    do
        ROLE=`basename $ROLE_PATH`
        gcloud iam roles --project=$PROJECT describe $ROLE \
               --format=json > $PROJECT.roles/$ROLE.json
    done
    gcloud services list --filter state:ENABLED --format=$format > $PROJECT.services.$format
    for service in `gcloud services list --filter state:ENABLED --format=json | jq -r .[].config.name`
    do
        case $service in
            compute.googleapis.com)
                echo TODO: Needs compute.projects.get
                #### gcloud compute project-info describe
                #### gcloud compute instances list --format=$format > $PROJECT.compute.instances.$format
                #### gcloud compute disks list --format=$format > $PROJECT.compute.disks.$format
                # I'm ensure why we see this when container.googleapis.com is DISABLED
                gcloud container clusters list --format=$format > $PROJECT.clusters.$format
                ;;
            dns.googleapis.com)
                mkdir -p dns
                gcloud dns project-info describe $PROJECT --format=$format > dns/$PROJECT.info.$format
                gcloud dns managed-zones list --format=$format > dns/$PROJECT.zones.$format
                ;;
            logging.googleapis.com)
                echo TODO: Needs serviceusage.services.use
                ##### gcloud logging logs list --format=$format > $PROJECT.logging.logs.$format
                ##### gcloud logging metrics list
                ##### gcloud logging sinks list
                ;;
            monitoring.googleapis.com)
                echo TODO: Needs serviceusage.services.use
                #### gcloud alpha monitoring policies list
                #### gcloud alpha monitoring channels list
                #### gcloud alpha monitoring channel-descriptors list
                ;;
            oslogin.googleapis.com)
                echo TODO: Verify how OS Login is configured / audited
                ;;
            bigquery-json.googleapis.com)
                echo TODO: Verify how Big Query is configured / audited
                ;;
            storage-api.googleapis.com)
                echo TODO: Add storage.buckets.get for auditors
                echo ...to kubernetes_public_billing and any newer buckets...
                echo TODO: Ensure bucket-policy-only, for simplicity in Auditing
                # https://cloud.google.com/storage/docs/bucket-policy-only
                mkdir -p buckets
                for BUCKET in `gsutil ls -p $PROJECT | awk -F/ '{print $3}'`
                do
                    #### gsutil bucketpolicyonly get gs://$BUCKET/
                    #### gsutil cors get gs://$BUCKET/
                    #### gsutil logging get gs://$BUCKET/
                    gsutil iam get gs://$BUCKET/ > buckets/$PROJECT.$BUCKET.iam.json
                    gsutil ls -r gs://$BUCKET/ > buckets/$PROJECT.$BUCKET.txt
                done
                ;;
            storage-component.googleapis.com)
                ;;
            *)
                echo ***** Unhandled Service *****
                ;;
        esac
    done
done


# TODO:
# Dump iam for each GCS Bucket
# Dump iam for Big Query
# Iterate over enabled APIs per project
# Identify each resource, then dump iam
