#! /bin/sh

# List of repos under https://console.cloud.google.com/gcr/images/k8s-staging-sig-storage/GLOBAL
repos="
csi-attacher
csi-node-driver-registrar
csi-provisioner
csi-resizer
csi-snapshotter
csi-external-health-monitor-agent
csi-external-health-monitor-controller
hostpathplugin
livenessprobe
mock-driver
nfs-provisioner
snapshot-controller
snapshot-validation-webhook
local-volume-provisioner
"

for repo in $repos; do
    echo "- name: $repo"
    echo "  dmap:"
    gcloud container images list-tags gcr.io/k8s-staging-sig-storage/$repo --format='get(digest, tags)' --filter='tags~^v AND NOT tags~v2020 AND NOT tags~-rc' --sort-by=tags |
        sed -e 's/\([^ ]*\)\t\(.*\)/    "\1": [ "\2" ]/'
done

