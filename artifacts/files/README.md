# Managing Kubernetes binary artifacts

This directory is for tools and things that are used to administer the GCS
buckets used to publish official binary artifacts for Kubernetes.

Buckets are created alongside GCR repositories, details
[here](../../k8s.gcr.io/README.md).

### File Promoter

The binary promoter is currently WIP.

To promote a binary artifact, follow these steps:

1. Upload the binary file to your staging GCS bucket. (E.g.,
   gs://k8s-staging-coredns).
1. Clone this git repo.
1. Add the file to the project manifest under `artifacts/files`
1. Create a PR to this git repo for your changes to the manifest [1].
1. The PR should trigger a `pull-k8sio-promobot-files` job; check that the `k8s-ci-robot`
   responds 'Job succeeded' for it.
1. Merge the PR. This will trigger the actual promotion (the `pull-k8sio-promobot-files`
   is just a dry run). The actual promotion job is called `post-k8sio-promobot-files` [2].

[1]: https://github.com/kubernetes-sigs/k8s-container-image-promoter/blob/master/cmd/promobot-files/README.md
[2]: https://k8s-testgrid.appspot.com/sig-release-misc#post-k8sio-promobot-files
