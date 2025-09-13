# registry.k8s.io

Kubernetes's multi-cloud image registry.

For more details on the design and implementation see the source repo: https://github.com/kubernetes/registry.k8s.io

Most of the deployment configuration is in [infra/gcp/terraform/k8s-infra-oci-proxy](./../infra/gcp/terraform/k8s-infra-oci-proxy) (staging instance for development only) and [infra/gcp/terraform/k8s-infra-oci-proxy-prod](./../infra/gcp/terraform/k8s-infra-oci-proxy-prod) (production / end users).

# Managing Kubernetes container registries

This directory is for tools and things that are used to administer the AR
repositories used to publish official container images for Kubernetes.

- [Staging repos](#staging-repos)
  - [Requirements](#requirements)
  - [Creating staging repos](#creating-staging-repos)
  - [Enabling automatic builds](#enabling-automatic-builds)
  - [Image Promoter](#image-promoter)
  - [Helm Chart Promotion](#helm-chart-promotion)

## Staging repos

~~Kubernetes subprojects may use a dedicated staging GCP project to build and
host container images. We refer to the GCR provided by each staging project
as a staging repository. Images are promoted from staging repositories into
the main Kubernetes image registry (registry.k8s.io).~~
This approach is deprecated and not accepted for new Kubernetes subprojects

We have a GCP project called k8s-staging-images with a dedicated registry for
each subproject. Maintainers can view the contents of the registry and push
images in exceptional situations. You can also retrigger jobs in Prow
if an image-push job failed by setting the rerun_auth_config as shown below.

> [!CAUTION]
> The staging image registries at us-central1-docker.pkg.dev/k8s-staging-images/\* have a 90 day retention policy.
> Please don't serve images to end users from there and follow the image promotion process below.

### Requirements

The rule of thumb is that staging repositories should be used to host
artifacts produced by code that is part of the Kubernetes project, as defined
by presence in one of the [project-owned GitHub Organizations][project-github].

In other words, code that is not part of the Kubernetes project should not
have its artifacts hosted in staging repos. SIG K8s Infra may make exceptions
to this policy on a case-by-case basis.

For example:

- CRI-O is not part of the kubernetes project, it does not meet the
  requirements to get a staging repo
- While coredns is not part of the kubernetes project, we do
  bundle them with kubernetes as part of the release, so for this specific
  case are allowing a staging repo to host them (solely within the context
  of the kubernetes project)

### Creating staging repos

1. Create a google group in the format `k8s-infra-staging-<project-name>@kubernetes.io` by using our [`groups`](../groups/README.md) tool.

1. Add the project name to the `locals.registries` list defined in
   [`infra/gcp/terraform/k8s-staging-images/registries.tf`][infra.yaml]

1. Someone from SIG K8s Lead will be pinged when you modify this file and apply the terraform changes on your behalf.

### Enabling automatic builds

Once your staging repo is up and running, you can enable automatic build and
push. For more info, see [the instructions here][image-pushing-readme]

NOTE: All sub-projects are _strongly_ encouraged to use this mechanism, though
it is not mandatory yet. Over time this will become the primary way to build
and push images, and anything else will become exceptional.

### Creating image promoter manifests

1. Enable automatic builds and ensure and image has been published by Cloud Build
   to the staging repo.

1. Create 3 files:

   - `images/k8s-staging-<project-name>/OWNERS`
   - `images/k8s-staging-<project-name>/images.yaml`
   - `manifests/k8s-staging-<project-name>/promoter-manifest.yaml`

The `promoter-manifest.yaml` file will house the credentials and other registry
metadata, whereas the `images.yaml` file will hold only the image data. You can
look at the existing staging repos for examples.

NOTE: For `images/k8s-staging-<project-name>/images.yaml`, it must not be empty as an image must be proposed
for promotion when you are opening this PR.

The separation between `promoter-manifest.yaml` and `images.yaml` is there to
prevent a single PR from modifying the source registry information as well as
the image information. Any changes to the `manifest/...` folder is expected to
be 1-time only during project setup.

Be sure to add the project owners to the
`images/k8s-staging-<project-name>/OWNERS` file to increase the number of
people who can approve new images for promotion for your project.

### Complete Example

1. Adding new groups [PR](https://github.com/kubernetes/k8s.io/pull/8447).
1. Staging Registry Creation & Image Promoter Manifest [PR](https://github.com/kubernetes/k8s.io/pull/8448).
1. Prow job that builds images on merge to main [PR](https://github.com/kubernetes/test-infra/pull/34376).

### Image Promoter

Image promotion roughly follows the following steps:

1. Push your image to one of the above staging docker repos
   e.g., us-central1-docker.pkg.dev/k8s-staging-images/minikube
2. Fork this git repo
3. Add the image into the promoter manifest
   e.g., if you pushed us-central1-docker.pkg.dev/k8s-staging-images/minikube/foo:1.3, then add a "foo"
   image entry into the manifest in `images/k8s-staging-minikube/images.yaml`
4. Create a PR to this git repo for your changes
5. The PR should trigger a `pull-k8sio-cip` job which will validate and dry-run
   your changes; check that the `k8s-ci-robot` responds 'Job succeeded' for it.
6. Merge the PR. Your image will be promoted by one of two jobs:
   - [`post-k8sio-image-promo`][post-promo-job] is a postsubmit that runs
     immediately after merge
   - [`ci-k8sio-cip`][ci-promo-job] is a periodic job that runs every four
     hours in case there are transient failures of the postsubmit jobs
7. Published images will be available at registry.k8s.io

We've written some tooling to simplify the creation of image promotion pull
requests, which is described in detail
[here](https://sigs.k8s.io/promo-tools/docs/promotion-pull-requests.md).

[google-groups]: /groups/README.md
[image-pushing-readme]: https://git.k8s.io/test-infra/config/jobs/image-pushing/README.md
[restrictions.yaml]: /groups/restrictions.yaml
[post-promo-job]: https://testgrid.k8s.io/sig-release-releng-blocking#post-k8sio-image-promo
[ci-promo-job]: https://testgrid.k8s.io/sig-release-releng-blocking#ci-k8sio-image-promo
[project-github]: https://git.k8s.io/community/github-management#project-owned-organizations

### Helm Chart Promotion

Publishing a Helm chart in the Kubernetes organization follows a process similar to
publishing an image.

1. The subproject should build, document and support the Helm chart.
2. The subproject should push the chart to the staging image repository.
3. Once the release has been created and the release job has been successful, obtain the SHA for the container images and the Helm charts from the build logs.
   This will be used later to promote these assets to `registry.k8s.io`
4. Update the image promoter manifest for your subproject (`registry.k8s.io/images/k8s-staging-SUBPROJECT/images.yaml`) to add the respective SHAs for the container images and the Helm charts that were pushed to the staging image repository
5. Create a PR and make sure that it gets merged for the image promoter process to kick off
6. Once the PR is merged, ensure the image promoter job for your merge commit is successful, then confirm that all promoted artifacts are available (e.g. `helm install subproject oci://registry.k8s.io/subproject/charts/subproject --version=$VERSION`)
