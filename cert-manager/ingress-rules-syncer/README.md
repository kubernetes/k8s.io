# ingress-rules-syncer

This is a controller used to mirror `rules` from one Ingress resource to another.

It has been created in response to [#1476](https://github.com/kubernetes/k8s.io/issues/1476).

## Usage

Add the label `ingress-rules-syncer.x-k8s.io/sync-from: "parent-ingress"` to an Ingress
resource and the `rules` from `parent-ingress` will be copied across to the labelled
Ingress whenever the parent changes.
