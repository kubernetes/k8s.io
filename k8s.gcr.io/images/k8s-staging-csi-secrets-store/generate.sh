#! /bin/sh

repos="
driver
"

for repo in $repos; do
    echo "- name: $repo"
    echo "  dmap:"
    gcloud container images list-tags gcr.io/k8s-staging-csi-secrets-store/$repo --format='get(digest, tags)' --filter='tags~^v AND NOT tags~-amd64 AND NOT tags~v0.0.11' | sed -e 's/\([^ ]*\)\t\(.*\)/    "\1": [ "\2" ]/'
done
