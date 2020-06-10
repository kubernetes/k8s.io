# k8s-artifacts-prod Runbook for GCR Image issues

## A bad image is detected by the auditor

### Image deletions or overwrites

Reinstate a known-good version of the image by re-running the [promoter][promoter] in
non-dry-run mode. This can be done by manually running the `post-k8sio-cip` Prow
job. Ask test-infra [oncall][oncall].

Running the `post-k8sio-cip` job successfully will restore all deleted images.
However, if an image tag is moved, the promoter cannot be used to overwrite the
tag back to the original because tag overwrites are not supported by the
promoter. Instead you have to use `gcrane` in order to restore the tag. If
there are multiple images that need this treatment, it is most likely best to
just run the `restore_prod.sh` script as below.

If the manual promotion run above fails to reinstate all original images, then run:

```
$ <k8s.io_ROOT>/infra/gcp/backup_tools/restore_prod.sh
```

to restore production from the backups.

### Validating image restorations

Simply re-run the promoter in dry-run mode. Anyone can do this (no permissions
are necessary in dry-drun mode). On a system without the promoter installed,
you would have to do:

```bash
cd $GOPATH/src/sigs.k8s.io
git clone https://github.com/kubernetes-sigs/k8s-container-image-promoter 2>/dev/null
cd k8s-container-image-promoter
make install # This makes "cip" available in your PATH.
cip -dry-run -thin-manifest-dir=<k8s.io_ROOT>/k8s.gcr.io
```

This should result in a message "Nothing to promote." at the end.

## Deploy a new auditor image

```
$ <k8s.io_ROOT>/infra/gcp/cip-auditor/deploy.sh <PROJECT_TO_RUN_IN> <SHA256_OF_IMAGE>
# Example: $ ./deploy.sh k8s-artifacts-prod d7b5d70c641a21b46564aa76f4d46af0854689b22109d8055f6429a061c57496
```

Note: The image is sourced from the
`us.gcr.io/k8s-artifacts-prod/artifact-promoter/cip-auditor` repository.

The auditor image runs on Cloud Run. It aggressively logs its findings (search for `VERIFIED` or `REJECTED`) into StackDriver logs.

[oncall]: http://go.k8s.io/oncall
[promoter]: https://github.com/kubernetes-sigs/k8s-container-image-promoter
