#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

CNCF_GCP_ORG=758905017065

echo "# Auditing CNCF CGP Org: ${CNCF_GCP_ORG} #"
mkdir -p org_kubernetes.io/roles
gcloud \
    iam roles list \
    --organization="${CNCF_GCP_ORG}" \
    --format="value(name)" \
| while read ROLE_PATH; do
    ROLE=$(basename "${ROLE_PATH}")
    gcloud iam roles describe "${ROLE}" \
        --organization="${CNCF_GCP_ORG}" \
        --format=json \
        > "org_kubernetes.io/roles/${ROLE}.json"
done
gcloud \
    organizations get-iam-policy "${CNCF_GCP_ORG}" \
    --format=json \
    > "org_kubernetes.io/iam.json"

echo "## Iterating over Projects ##"
gcloud \
    projects list \
    --filter="parent.id=${CNCF_GCP_ORG}" \
    --format="value(name, projectNumber)" \
| sort \
| while read PROJECT NUM; do
    export CLOUDSDK_CORE_PROJECT="${PROJECT}"

    echo "### Auditing Project ${PROJECT} ###"
    mkdir -p "${PROJECT}"
    gcloud \
        projects describe "${PROJECT}" \
        --format=json \
        > "${PROJECT}/description.json"

    echo "#### ${PROJECT} IAM ####"
    gcloud \
        projects get-iam-policy "${PROJECT}" \
        --format=json \
        > "${PROJECT}/iam.json"

    echo "#### ${PROJECT} ServiceAccounts ####"
    gcloud \
        iam service-accounts list \
        --project="${PROJECT}" \
        --format="value(email)" \
    | while read SVCACCT; do
        mkdir -p "${PROJECT}/service-accounts/${SVCACCT}"
        gcloud \
            iam service-accounts describe "${SVCACCT}" \
            --project="${PROJECT}" \
            --format=json \
            > "${PROJECT}/service-accounts/${SVCACCT}/description.json"
        gcloud \
            iam service-accounts get-iam-policy "${SVCACCT}" \
            --project="${PROJECT}" \
            --format=json \
            > "${PROJECT}/service-accounts/${SVCACCT}/iam.json"
    done

    echo "#### ${PROJECT} Roles ####"
    gcloud \
        iam roles list \
        --project="${PROJECT}" \
        --format="value(name)" \
    | while read ROLE_PATH; do
        mkdir -p "${PROJECT}/roles"
        ROLE=$(basename "${ROLE_PATH}")
        gcloud \
            iam roles describe "${ROLE}" \
            --project="${PROJECT}" \
            --format=json \
            > "${PROJECT}/roles/${ROLE}.json"
    done

    echo "#### Services ####"
    gcloud \
        services list \
        --filter="state:ENABLED" \
        --format=json \
        > "${PROJECT}/services/enabled.json"
    gcloud \
        services list \
        --filter="state:ENABLED" \
        --format="value(config.name)" \
    | sed 's/.googleapis.com//' \
    | sort \
    | while read SVC; do
        case "${SVC}" in
            compute)
                mkdir -p "${PROJECT}/services/${SVC}"
                gcloud \
                    compute project-info describe \
                    --project="${PROJECT}" \
                    --format=json \
                    > "${PROJECT}/services/${SVC}/project-info.json"
                ;;
            container)
                mkdir -p "${PROJECT}/services/${SVC}"
                # Don't do a JSON dump here - too much changes without human
                # action.
                gcloud \
                    container clusters list \
                    --format="value(name, location, locations, currentNodeCount, status)" \
                    > "${PROJECT}/services/${SVC}/clusters.txt"
                ;;
            dns)
                mkdir -p "${PROJECT}/services/${SVC}"
                gcloud \
                    dns project-info describe "${PROJECT}" \
                    --format=json \
                    > "${PROJECT}/services/${SVC}/info.json"
                gcloud \
                    dns managed-zones list \
                    --format=json \
                    > "${PROJECT}/services/${SVC}/zones.json"
                ;;
            logging)
                echo "TODO: ${SVC} needs serviceusage.services.use"
                ##### gcloud logging logs list --format=json > "${PROJECT}/services/logging.logs.json"
                ##### gcloud logging metrics list --format=json > "${PROJECT}/services/logging.metrics.json"
                ##### gcloud logging sinks list --format=json > "${PROJECT}/services/logging.sinks.json"
                ;;
            monitoring)
                echo "TODO: ${SVC} needs serviceusage.services.use"
                #### gcloud alpha monitoring policies list > "${PROJECT}/services/monitoring.policies.json"
                #### gcloud alpha monitoring channels list > "${PROJECT}/services/monitoring.channels.json"
                #### gcloud alpha monitoring channel-descriptors list > "${PROJECT}/services/monitoring.channel-descriptors.json"
                ;;
            storage-api)
                gsutil ls -p "${PROJECT}" \
                | awk -F/ '{print $3}' \
                | while read BUCKET; do
                    mkdir -p "${PROJECT}/buckets/${BUCKET}"
                    gsutil bucketpolicyonly get "gs://${BUCKET}/" \
                        > "${PROJECT}/buckets/${BUCKET}/bucketpolicyonly.json"
                    gsutil cors get "gs://${BUCKET}/" \
                        > "${PROJECT}/buckets/${BUCKET}/cors.json"
                    gsutil logging get "gs://${BUCKET}/" \
                        > "${PROJECT}/buckets/${BUCKET}/logging.json"
                    gsutil iam get "gs://${BUCKET}/" \
                        > "${PROJECT}/buckets/${BUCKET}/iam.json"
                done
                ;;
            *)
                echo "# Unhandled Service ${SVC} #"
                ;;
        esac
    done
done


# TODO:
# Dump iam for Big Query
