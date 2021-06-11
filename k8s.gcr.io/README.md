# Managing Kubernetes container registries

This directory is for tools and things that are used to administer the GCR
repositories used to publish official container images for Kubernetes.

## Staging repos

Each "project" (as decided by people) that feeds into Kubernetes' main
image-serving system (k8s.gcr.io) gets a staging repository.  Each staging
repository is governed by a googlegroup, which grants push access to that
repository.

Project owners can push to their staging repository and use the image promoter
to promote images to the main serving repository.

### Creating staging repos

1. Create a google group for granting push access by adding an email
alias for it in [groups.yaml]. The email alias should be of the form
`k8s-infra-staging-<project-name>@kubernetes.io`. The project name
can have a maximum of 18 characters.

2. Create 3 files:
    - `images/k8s-staging-<project-name>/OWNERS`
    - `images/k8s-staging-<project-name>/images.yaml`
    - `manifests/k8s-staging-<project-name>/promoter-manifest.yaml`

The `promoter-manifest.yaml` file will house the credentials and other registry
metadata, whereas the `images.yaml` file will hold only the image data. You can
look at the existing staging repos for examples.

NOTE: For `images/k8s-staging-<project-name>/images.yaml`, if you have no images
to upload at this time, you must still create a blank file, like this:

```
# No images yet
```

The separation between `promoter-manifest.yaml` and `images.yaml` is there to
prevent a single PR from modifying the source registry information as well as
the image information. Any changes to the `manifest/...` folder is expected to
be 1-time only during project setup.

Be sure to add the project owners to the
`images/k8s-staging-<project-name>/OWNERS` file to increase the number of
people who can approve new images for promotion for your project.

3. Add the project name to the `infra.staging.projects` list defined in
   [`infra/gcp/infra.yaml`][infra.yaml]

4. One your PR merges:
    - a postsubmit job will create the necessary google group
    - whoever approved your PR will run [the necessary bash script(s)][staging-bash]
      to create the staging repo

### Enabling automatic builds

Once your staging repo is up and running, you can enable automatic build and
push.  For more info, see [the instructions here][image-pushing-readme]

NOTE: All sub-projects are *strongly* encouraged to use this mechanism, though
it is not mandatory yet.  Over time this will become the primary way to build
and push images, and anything else will become exceptional.

### Image Promoter

To promote an image, follow these steps:

1. Push your image to one of the above staging docker repos. (E.g.,
   gcr.io/k8s-staging-coredns).
1. Clone this git repo.
1. Add the image into the promoter manifest. E.g., if you pushed
   gcr.io/k8s-staging-coredns/foo:1.3, then add a "foo" image entry into the
   manifest in `images/k8s-staging-coredns/images.yaml`.
1. Create a PR to this git repo for your changes.
1. The PR should trigger a `pull-k8sio-cip` job which will validate and dry-run
   your changes; check that the `k8s-ci-robot` responds 'Job succeeded' for it.
1. Merge the PR. Your image will be promoted by one of two jobs:
   - [`post-k8sio-image-promo`][post-promo-job] is a postsubmit that runs immediately after merge
   - [`ci-k8sio-cip`][ci-promo-job] is a postsubmit that runs immediately after merge
1. A periodic 
1. Published images will appear on k8s.gcr.io and can be viewed [here](https://console.cloud.google.com/gcr/images/k8s-artifacts-prod).

Essentially, in order to get images published to a production repo, you have to
use the image promotion (PR creation) process defined above.

[image-pushing-readme]: https://git.k8s.io/test-infra/config/jobs/image-pushing/README.md
[groups.yaml]: /groups/groups.yaml
[infra.yaml]: /infra/gcp/infra.yaml
[staging-bash]: /infra/gcp/ensure-staging-storage.sh
[vdf]: /k8s.gcr.io/Vanity-Domain-Flip.md
[post-promo-job]: https://testgrid.k8s.io/sig-release-releng-blocking#post-k8sio-image-promo
[ci-promo-job]: https://testgrid.k8s.io/sig-release-releng-blocking#ci-k8sio-image-promo
