# Managing Kubernetes container regstries

This directory is for tools and things that are used to administer the GCR
repositories used to publish official container images for Kubernetes.

## Staging repos

Each "project" (as decided by people) that feeds into Kubernetes' main
image-serving system (k8s.gcr.io) gets a staging repository.  Each staging
repository is governed by a googlegroup, which grants push access to that
repository.

Project owners can push to their staging repository and use the image promoter
to promote images to the main serving repository.

**Note**: Currently, the image promoter is WIP so main serving repositories
cannot be used yet. Only staging repositories can be used. 

### Creating staging repos

1. Create a google group for granting push access by adding an email
alias for it in [groups.yaml]. The email alias should be of the form
`k8s-infra-staging-<project-name>@kubernetes.io`. The project name
can have a maximum of 18 characters.

2. Create a directory `k8s-staging-<project-name>` and add a manifest
file for it. You can look at the existing staging repos for examples.

3. Add the project name to `STAGING_PROJECTS` in
   [ensure-staging-storage.sh].

4. Once the PR merges:
    - ping @dims or @cblecker to create the necessary google group.
    - ping @thockin or @justinsb to run [ensure-staging-storage.sh] to create
    the staging repo.

### Image Promoter

The image promoter is currently WIP.

To promote an image, follow these steps:

1. Push your image to one of the above staging docker repos. (E.g.,
   gcr.io/k8s-staging-coredns).
1. Clone this git repo.
1. Add the image into the promoter manifest. E.g., if you pushed
   gcr.io/k8s-staging-coredns/foo:1.3, then add a "foo" image entry into the
   manifest.
1. Create a PR to this git repo for your changes to the promoter manifest.
1. The PR should trigger a `pull-k8sio-cip` job; check that the `k8s-ci-robot`
   responds 'Job succeeded' for it.
1. Merge the PR. This will trigger the actual promotion (the `pull-k8sio-cip`
   is just a dry run). The actual promotion job is called `post-k8sio-cip` [1].

Essentially, in order to get images published to a production repo, you have to
use the image promotion (PR creation) process defined above.

[1]: https://k8s-testgrid.appspot.com/sig-release-misc#post-k8sio-cip
[ensure-staging-storage.sh]: /infra/gcp/ensure-staging-storage.sh
[groups.yaml]: /groups/groups.yaml
