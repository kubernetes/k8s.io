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

As of Feb 11, 2019 this hierarchical system, including the promoter, are a
work-in-progress.
