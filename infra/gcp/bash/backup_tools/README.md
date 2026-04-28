# Backup tools

The tools in this folder are designed to backup the
{asia,eu,us}.gcr.io/k8s-artifacts-prod GCRs.

The entrypoint is the `backup_prod.sh` script which backs up all images in the
3 prod regions (asia, eu, us) for the `k8s-artifacts-prod` project. For each
region, an hourly snapshot is created by copying images into a backup GCR, but
under a toplevel folder named after the hourly timestamp (UTC). This is so that
we don't overwrite old backups.

## Backup test

The backup test works by

1. seeding a known set of images by copying them from us.gcr.io/k8s-artifacts-prod to us.gcr.io/k8s-gcr-backup-test-prod,
2. backing them up to us.gcr.io/k8s-gcr-backup-test-prod-bak, and
3. checking the repository contents.

The backup test does not bother testing the backup of all 3 regions, because
adding more regions does not add useful data points.
