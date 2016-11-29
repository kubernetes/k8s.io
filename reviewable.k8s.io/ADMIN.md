# Notes for people administering reviewable.kubernetes.io

Our instance of reviewable is locked to the kubernetes org.  It can not be used
for anything else.

All usernames and passwords are stored in the Google password vault.

Dockerhub account to access reviewable:
  - only used for pulling Reviewable container images

Github account for reviewable API access:
  - should never be needed
  - represents a random person on internet, must not be added to any org
  - passed to reviewable binary

Firebase:
  - account is linked to thockin@google.com and krousey@google.com
  - passed to reviewable binary
  - https://reviewable-k8s.firebaseio.com

Sentry:
  - passed to reviewable binary
  - we're not using it, but reviewable is collecting crashes on our behalf

Kubernetes configs:
  - running in GKE "utilicluster" in the "kubernetes-site" project
  - everything is in the "reviewable" namespace

DNS:
  - reviewable.kubernetes.io is the primary name
  - managed in the "kubernetes-site" project
  - reviewable.k8s.io is a CNAME to k8s.io, which redirects to
    reviewable.kubernetes.io

## TODO

Still to do:
  - upgrade our firebase account
  - Logging, monitoring, and alerting
  - Use an HPA to scale
  - Email setup
