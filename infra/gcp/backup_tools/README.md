# Backup tools

The tools in this folder are designed to backup the
{asia,eu,us}.gcr.io/k8s-artifacts-prod GCRs.

The entrypoint is the `backup.sh` script which backs up all images in the 3 prod
regions (asia, eu, us) for the `k8s-artifacts-prod` project. For each region, an
hourly snapshot is created by copying images into a backup GCR, but under a
toplevel folder named after the hourly timestamp (UTC). This is so that we don't
overwrite old backups.
