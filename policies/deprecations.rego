package main

warn[msg] {
  input.apiVersion != "v1"
  input.kind != "List"
  msg := _warn
}

# All resources will no longer be served from rbac.authorization.k8s.io/v1alpha1 and rbac.authorization.k8s.io/v1beta1 in 1.20. Migrate to use rbac.authorization.k8s.io/v1 instead
_warn = msg {
  apis := ["rbac.authorization.k8s.io/v1alpha1", "rbac.authorization.k8s.io/v1beta1"]
  input.apiVersion == apis[_]
  msg := sprintf("%s/%s: API %s is deprecated from Kubernetes 1.20, use rbac.authorization.k8s.io/v1 instead.", [input.kind, input.metadata.name, input.apiVersion])
}

# All resources under apps/v1beta1 and apps/v1beta2 - use apps/v1 instead
_warn = msg {
  apis := ["apps/v1beta1", "apps/v1beta2"]
  input.apiVersion == apis[_]
  msg := sprintf("%s/%s: API %s has been deprecated, use apps/v1 instead.", [input.kind, input.metadata.name, input.apiVersion])
}

# daemonsets, deployments, replicasets resources under extensions/v1beta1 - use apps/v1 instead
_warn = msg {
  resources := ["DaemonSet", "Deployment", "ReplicaSet"]
  input.apiVersion == "extensions/v1beta1"
  input.kind == resources[_]
  msg := sprintf("%s/%s: API extensions/v1beta1 for %s has been deprecated, use apps/v1 instead.", [input.kind, input.metadata.name, input.kind])
}

# Ingress resources extensions/v1beta1 will no longer be served from in v1.20. Migrate use to the networking.k8s.io/v1beta1 API, available since v1.14.
_warn = msg {
  input.apiVersion == "extensions/v1beta1"
  input.kind == "Ingress"
  msg := sprintf("%s/%s: API extensions/v1beta1 for Ingress is deprecated from Kubernetes 1.14, use networking.k8s.io/v1beta1 instead.", [input.kind, input.metadata.name])
}
