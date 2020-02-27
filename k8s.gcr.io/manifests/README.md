# GCR Manifests

This directory holds the manifest metadata for all of our sub-projects.  These
files define the source and destination repos and paths that the promoter is
allowed to operate on.

These subdirectories MUST NOT have delegated OWNERS files - they represent
sensitive configuration that needs careful review, and should almost never
change.

Reviewers should ensure that:
* The source registry is one that we trust.
* There is one non-source registry for each of {us, eu, asia}.
* The non-source registries include an appropriate "subdir" for the
  sub-project (e.g. src `gcr.io/k8s-staging-foobar` promotes to
  `{us,eu,asia}.gcr.io/k8s-artifacts-prod/foobar`).  Exceptions to this are
  very rare and must be commented and linked to a PR with discussion.
* The service account is correct.
