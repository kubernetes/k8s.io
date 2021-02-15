#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

CNCF_GCP_ORG=758905017065

echo "# Removing existing audit files"
rm -rf org_kubernetes.io
rm -rf projects

echo "# Auditing CNCF CGP Org: ${CNCF_GCP_ORG}"
mkdir -p org_kubernetes.io/roles
gcloud \
    iam roles list \
    --organization="${CNCF_GCP_ORG}" \
    --format="value(name)" \
| while read -r ROLE_PATH; do
    ROLE=$(basename "${ROLE_PATH}")
    gcloud iam roles describe "${ROLE}" \
        --organization="${CNCF_GCP_ORG}" \
        --format=json \
        | jq 'del(.etag)' \
        > "org_kubernetes.io/roles/${ROLE}.json"
done
gcloud \
    organizations get-iam-policy "${CNCF_GCP_ORG}" \
    --format=json \
    | jq 'del(.etag)' \
    > "org_kubernetes.io/iam.json"

echo "## Iterating over Projects"
gcloud \
    projects list \
    --filter="parent.id=${CNCF_GCP_ORG}" \
    --format="value(name, projectNumber)" \
| sort \
| while read -r PROJECT NUM; do
    export CLOUDSDK_CORE_PROJECT="${PROJECT}"

    echo "### Auditing Project ${PROJECT}"
    mkdir -p "projects/${PROJECT}"
    gcloud \
        projects describe "${PROJECT}" \
        --format=json \
        > "projects/${PROJECT}/description.json"

    echo "#### ${PROJECT} IAM"
    gcloud \
        projects get-iam-policy "${PROJECT}" \
        --format=json \
        | jq 'del(.etag)' \
        > "projects/${PROJECT}/iam.json"

    echo "#### ${PROJECT} ServiceAccounts"
    gcloud \
        iam service-accounts list \
        --project="${PROJECT}" \
        --format="value(email)" \
    | while read -r SVCACCT; do
        mkdir -p "projects/${PROJECT}/service-accounts/${SVCACCT}"
        gcloud \
            iam service-accounts describe "${SVCACCT}" \
            --project="${PROJECT}" \
            --format=json \
            | jq 'del(.etag)' \
            > "projects/${PROJECT}/service-accounts/${SVCACCT}/description.json"
        gcloud \
            iam service-accounts get-iam-policy "${SVCACCT}" \
            --project="${PROJECT}" \
            --format=json \
            | jq 'del(.etag)' \
            > "projects/${PROJECT}/service-accounts/${SVCACCT}/iam.json"
    done

    echo "#### ${PROJECT} Roles"
    gcloud \
        iam roles list \
        --project="${PROJECT}" \
        --format="value(name)" \
    | while read -r ROLE_PATH; do
        mkdir -p "projects/${PROJECT}/roles"
        ROLE=$(basename "${ROLE_PATH}")
        gcloud \
            iam roles describe "${ROLE}" \
            --project="${PROJECT}" \
            --format=json \
            | jq 'del(.etag)' \
            > "projects/${PROJECT}/roles/${ROLE}.json"
    done

    echo "#### Services"
    mkdir -p "projects/${PROJECT}/services"
    gcloud \
        services list \
        --filter="state:ENABLED" \
        > "projects/${PROJECT}/services/enabled.txt"
    gcloud \
        services list \
        --filter="state:ENABLED" \
        --format="value(config.name)" \
    | sed 's/.googleapis.com//' \
    | while read -r SVC; do
        case "${SVC}" in
            bigquery)
                mkdir -p "projects/${PROJECT}/services/${SVC}"
                bq \
                    --format=prettyjson --project_id=$PROJECT ls
                    > "projects/${PROJECT}/services/${SVC}/bigquery.datasets.json"                
                # Only run if there are any datasets
                if [ -s "projects/${PROJECT}/services/${SVC}/bigquery.datasets.json" ]
                then
                    bq \
                        --project_id="{$PROJECT}" --format=json ls \
                        | jq -r '.[] | .datasetReference["datasetId"]' \
                        | while read -r DATASET; do                        
                            bq \
                                --project_id="${PROJECT}" --format=json show "${PROJECT}:${DATASET}" \
                            | jq .access > "projects/${PROJECT}/services/${SVC}/bigquery.datasets.${DATASET}.access.json"
                        done
                fi
                ;;
            compute)
                mkdir -p "projects/${PROJECT}/services/${SVC}"
                gcloud \
                    compute project-info describe \
                    --project="${PROJECT}" \
                    --format=json \
                    | jq 'del(.quotas[].usage, .commonInstanceMetadata.fingerprint)' \
                    > "projects/${PROJECT}/services/${SVC}/project-info.json"
                ;;
            container)
                mkdir -p "projects/${PROJECT}/services/${SVC}"
                # Don't do a JSON dump here - too much changes without human
                # action.
                gcloud \
                    container clusters list \
                    --format="value(name, location, locations, currentNodeCount, status)" \
                    > "projects/${PROJECT}/services/${SVC}/clusters.txt"
                ;;
            dns)
                mkdir -p "projects/${PROJECT}/services/${SVC}"
                gcloud \
                    dns project-info describe "${PROJECT}" \
                    --format=json \
                    > "projects/${PROJECT}/services/${SVC}/info.json"
                gcloud \
                    dns managed-zones list \
                    --format=json \
                    > "projects/${PROJECT}/services/${SVC}/zones.json"
                ;;
            logging)
                echo "TODO: ${SVC} needs serviceusage.services.use"
                ##### gcloud logging logs list --format=json > "projects/${PROJECT}/services/logging.logs.json"
                ##### gcloud logging metrics list --format=json > "projects/${PROJECT}/services/logging.metrics.json"
                ##### gcloud logging sinks list --format=json > "projects/${PROJECT}/services/logging.sinks.json"
                ;;
            monitoring)
                echo "TODO: ${SVC} needs serviceusage.services.use"
                #### gcloud alpha monitoring policies list > "projects/${PROJECT}/services/monitoring.policies.json"
                #### gcloud alpha monitoring channels list > "projects/${PROJECT}/services/monitoring.channels.json"
                #### gcloud alpha monitoring channel-descriptors list > "projects/${PROJECT}/services/monitoring.channel-descriptors.json"
                ;;
            # secretmanager)
            #     gcloud \
            #         secrets list \
            #         --project=k8s-gsuite \
            #         --format="value(name)" \
            #     | while read -r SECRET; do
            #         path="projects/${PROJECT}/secrets/${SECRET}"
            #         mkdir -p "${path}"
            #         gcloud \
            #             secrets describe "${SECRET}" \
            #             --project="${PROJECT}" \
            #             --format=json \
            #             > "${path}/description.json"
            #         gcloud \
            #             secrets versions list "${SECRET}" \
            #             --project="${PROJECT}" \
            #             --format=json \
            #             > "${path}/versions.json"
            #         gcloud \
            #             secrets get-iam-policy "${SECRET}" \
            #             --project="${PROJECT}" \
            #             --format=json \
            #             | jq 'del(.etag)' \
            #             > "${path}/iam.json"
            #     done
            #     ;;
            storage-api)
                gsutil ls -p "${PROJECT}" \
                | awk -F/ '{print $3}' \
                | while read -r BUCKET; do
                    mkdir -p "projects/${PROJECT}/buckets/${BUCKET}"
                    gsutil bucketpolicyonly get "gs://${BUCKET}/" \
                        > "projects/${PROJECT}/buckets/${BUCKET}/bucketpolicyonly.txt"
                    gsutil cors get "gs://${BUCKET}/" \
                        > "projects/${PROJECT}/buckets/${BUCKET}/cors.txt"
                    gsutil logging get "gs://${BUCKET}/" \
                        > "projects/${PROJECT}/buckets/${BUCKET}/logging.txt"
                    gsutil iam get "gs://${BUCKET}/" \
                        | jq 'del(.etag)' \
                        > "projects/${PROJECT}/buckets/${BUCKET}/iam.json"
                done
                ;;
            *)
                echo "##### Unhandled Service ${SVC}"
                ;;
        esac
    done
done


# TODO:
# Dump iam for Big Query
