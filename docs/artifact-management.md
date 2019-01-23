# Artifact Management

## Overview
This document describes how official artifacts (Container Images, Binaries) for the Kubernetes
project are managed and distributed.

## Goals
The goals of this process are to enable:
  * Anyone in the community (with the right permissions) to manage the distribution of Kubernetes images and binaries.
  * Fast, cost-efficient access to artifacts around the world through appropriate mirrors and distribution

## Design
The top level design will be to set up a global redirector HTTP service (`artifacts.k8s.io`) 
which knows how to serve HTTP and redirect requests to an appropriate mirror. This redirector
will serve both binary and container image downloads. For container images, the HTTP redirector
will redirect users to the appropriate geo-located container registry. For binary artifacts, 
the HTTP redirector will redirect to appropriate geo-located storage buckets.

## Artifact Promotion
To facilitate artifact promotion, each project, as necessary, will be given access to a
project staging area relevant to their particular artifacts (either storage bucket or image 
registry). Each project is free to manage their assets in the staging area however they feel
it is best to do so. However, end-users are not expected to access artifacts through the
staging area.

For each artifact, there will be a configuration file checked into this repository. When a
project wants to promote an image, they will file a PR in this repository to update their
image promotion configuration to promote an artifact from staging to production. Once this
PR is approved, automation that is running in the k8s project infrastructure (e.g. https://github.com/GoogleCloudPlatform/k8s-container-image-promoter) will pick up this new
configuration file and copy the relevant bits out to the production serving locations.

Importantly, if a project needs to roll-back or remove an artifact, the same process will
occur, so that the promotion tool needs to be capable of deleting images and artifacts as
well as promoting them.
