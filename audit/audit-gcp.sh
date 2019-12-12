#!/bin/bash
# set -x -e
CNCF_GCP_ORG=758905017065

# gcloud organizations describe $CNCF_GCP_ORG 2>&1
# ERROR: (gcloud.organizations.describe)
# User [hh@ii.coop] does not have permission to access organization []

format=json

echo "# Auditing CNCF CGP Org: ${CNCF_GCP_ORG} #"
mkdir -p org_kubernetes.io/roles
for ROLE_PATH in $(gcloud iam roles list --organization=$CNCF_GCP_ORG --format="value(name)")
do
    ROLE=$(basename $ROLE_PATH)
    gcloud iam roles describe --organization=$CNCF_GCP_ORG $ROLE \
        --format=json > org_kubernetes.io/roles/$ROLE.json
done
gcloud organizations get-iam-policy $CNCF_GCP_ORG --format=$format \
       > org_kubernetes.io/iam.$format

echo "## Iterating over Projects ##"
gcloud projects list \
       --filter "parent.id=$CNCF_GCP_ORG" \
       --format "value(name, projectNumber)" \
    | sort \
    | while read PROJECT NUM; do \
    export CLOUDSDK_CORE_PROJECT=$PROJECT
    echo "### Auditing Project: ${PROJECT} ###"
    mkdir -p $PROJECT
    gcloud projects get-iam-policy $PROJECT --format=$format > $PROJECT/iam.$format
    mkdir -p $PROJECT/roles
    for ROLE_PATH in $(gcloud iam roles list --project $PROJECT --format="value(name)")
    do
        ROLE=$(basename $ROLE_PATH)
        gcloud iam roles --project=$PROJECT describe $ROLE \
               --format=json > $PROJECT/roles/$ROLE.json
    done

    echo "#### Iterating over ${PROJECT} Services: ####"
    mkdir -p $PROJECT/services
    gcloud services list --filter state:ENABLED --format=$format > $PROJECT/services/enabled.$format
    for service in $(gcloud services list --filter state:ENABLED --format=json \
                    | jq -r .[].config.name | sed s:.googleapis.com:: \
                    | sort)
    do
        case $service in
            compute)
                echo TODO: $service Needs compute.projects.get
                #### gcloud compute project-info describe
                #### gcloud compute instances list --format=$format > $PROJECT/services/compute.instances.$format
                #### gcloud compute disks list --format=$format > $PROJECT/services/compute.disks.$format
                ;;
            container)
                # Don't do a JSON dump here - too much changes without human
                # action.
                mkdir -p $PROJECT/services/container
                gcloud container clusters list > $PROJECT/services/container/clusters.txt
                ;;
            dns)
                mkdir -p $PROJECT/services/dns
                gcloud dns project-info describe $PROJECT --format=$format > $PROJECT/services/dns/info.$format
                gcloud dns managed-zones list --format=$format > $PROJECT/services/dns/zones.$format
                ;;
            logging)
                echo TODO: $service needs serviceusage.services.use
                ##### gcloud logging logs list --format=$format > $PROJECT/services/logging.logs.$format
                ##### gcloud logging metrics list --format=$format > $PROJECT/services/logging.metrics.$format
                ##### gcloud logging sinks list --format=$format > $PROJECT/services/logging.sinks.$format
                ;;
            monitoring)
                echo TODO: $service needs serviceusage.services.use
                #### gcloud alpha monitoring policies list > $PROJECT/services/monitoring.policies.$format
                #### gcloud alpha monitoring channels list > $PROJECT/services/monitoring.channels.$format
                #### gcloud alpha monitoring channel-descriptors list > $PROJECT/services/monitoring.channel-descriptors.$format
                ;;
            oslogin)
                echo TODO: Verify how OS Login is configured / audited
                ;;
            bigquery-json)
                echo TODO: Verify how Big Query is configured / audited
                ;;
            storage-api)
                for BUCKET in $(gsutil ls -p $PROJECT | awk -F/ '{print $3}')
                do
                    mkdir -p $PROJECT/buckets/$BUCKET
                    gsutil bucketpolicyonly get gs://$BUCKET/ > $PROJECT/buckets/$BUCKET/bucketpolicyonly.json
                    gsutil cors get gs://$BUCKET/ > $PROJECT/buckets/$BUCKET/cors.json
                    gsutil logging get gs://$BUCKET/ > $PROJECT/buckets/$BUCKET/logging.json
                    gsutil iam get gs://$BUCKET/ > $PROJECT/buckets/$BUCKET/iam.json
                done
                ;;
            storage-component)
                ;;
            *)
                echo "# Unhandled Service ${service} #"
                ;;
        esac
    done
done


# TODO:
# Dump iam for Big Query
# Iterate over enabled APIs per project
# Identify each resource, then dump iam
