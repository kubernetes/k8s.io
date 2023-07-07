/*
Copyright 2023 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

# Source: https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
# Generated with tfk8s:
# tfk8s -f cluster-autoscaler.yaml -o cluster-autoscaler.tf

resource "kubernetes_manifest" "serviceaccount_kube_system_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "annotations" = {
        "eks.amazonaws.com/role-arn" = var.cluster_autoscaler_iam_role_arn
      }
      "labels" = {
        "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
        "k8s-app"   = "cluster-autoscaler"
      }
      "name"      = "cluster-autoscaler"
      "namespace" = "kube-system"
    }
  }
}

resource "kubernetes_manifest" "clusterrole_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRole"
    "metadata" = {
      "labels" = {
        "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
        "k8s-app"   = "cluster-autoscaler"
      }
      "name" = "cluster-autoscaler"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "events",
          "endpoints",
        ]
        "verbs" = [
          "create",
          "patch",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "pods/eviction",
        ]
        "verbs" = [
          "create",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "pods/status",
        ]
        "verbs" = [
          "update",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resourceNames" = [
          "cluster-autoscaler",
        ]
        "resources" = [
          "endpoints",
        ]
        "verbs" = [
          "get",
          "update",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "nodes",
        ]
        "verbs" = [
          "watch",
          "list",
          "get",
          "update",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "namespaces",
          "pods",
          "services",
          "replicationcontrollers",
          "persistentvolumeclaims",
          "persistentvolumes",
        ]
        "verbs" = [
          "watch",
          "list",
          "get",
        ]
      },
      {
        "apiGroups" = [
          "extensions",
        ]
        "resources" = [
          "replicasets",
          "daemonsets",
        ]
        "verbs" = [
          "watch",
          "list",
          "get",
        ]
      },
      {
        "apiGroups" = [
          "policy",
        ]
        "resources" = [
          "poddisruptionbudgets",
        ]
        "verbs" = [
          "watch",
          "list",
        ]
      },
      {
        "apiGroups" = [
          "apps",
        ]
        "resources" = [
          "statefulsets",
          "replicasets",
          "daemonsets",
        ]
        "verbs" = [
          "watch",
          "list",
          "get",
        ]
      },
      {
        "apiGroups" = [
          "storage.k8s.io",
        ]
        "resources" = [
          "storageclasses",
          "csinodes",
          "csidrivers",
          "csistoragecapacities",
        ]
        "verbs" = [
          "watch",
          "list",
          "get",
        ]
      },
      {
        "apiGroups" = [
          "batch",
          "extensions",
        ]
        "resources" = [
          "jobs",
        ]
        "verbs" = [
          "get",
          "list",
          "watch",
          "patch",
        ]
      },
      {
        "apiGroups" = [
          "coordination.k8s.io",
        ]
        "resources" = [
          "leases",
        ]
        "verbs" = [
          "create",
        ]
      },
      {
        "apiGroups" = [
          "coordination.k8s.io",
        ]
        "resourceNames" = [
          "cluster-autoscaler",
        ]
        "resources" = [
          "leases",
        ]
        "verbs" = [
          "get",
          "update",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "role_kube_system_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "Role"
    "metadata" = {
      "labels" = {
        "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
        "k8s-app"   = "cluster-autoscaler"
      }
      "name"      = "cluster-autoscaler"
      "namespace" = "kube-system"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "configmaps",
        ]
        "verbs" = [
          "create",
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "",
        ]
        "resourceNames" = [
          "cluster-autoscaler-status",
          "cluster-autoscaler-priority-expander",
        ]
        "resources" = [
          "configmaps",
        ]
        "verbs" = [
          "delete",
          "get",
          "update",
          "watch",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrolebinding_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRoleBinding"
    "metadata" = {
      "labels" = {
        "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
        "k8s-app"   = "cluster-autoscaler"
      }
      "name" = "cluster-autoscaler"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind"     = "ClusterRole"
      "name"     = "cluster-autoscaler"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "cluster-autoscaler"
        "namespace" = "kube-system"
      },
    ]
  }
}

resource "kubernetes_manifest" "rolebinding_kube_system_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "RoleBinding"
    "metadata" = {
      "labels" = {
        "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
        "k8s-app"   = "cluster-autoscaler"
      }
      "name"      = "cluster-autoscaler"
      "namespace" = "kube-system"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind"     = "Role"
      "name"     = "cluster-autoscaler"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "cluster-autoscaler"
        "namespace" = "kube-system"
      },
    ]
  }
}

resource "kubernetes_manifest" "deployment_kube_system_cluster_autoscaler" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind"       = "Deployment"
    "metadata" = {
      "labels" = {
        "app" = "cluster-autoscaler"
      }
      "name"      = "cluster-autoscaler"
      "namespace" = "kube-system"
    }
    "spec" = {
      "replicas" = 0
      "selector" = {
        "matchLabels" = {
          "app" = "cluster-autoscaler"
        }
      }
      "template" = {
        "metadata" = {
          "annotations" = {
            "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
            "prometheus.io/port"                             = "8085"
            "prometheus.io/scrape"                           = "true"
          }
          "labels" = {
            "app" = "cluster-autoscaler"
          }
        }
        "spec" = {
          "containers" = [
            {
              "command" = [
                "./cluster-autoscaler",
                "--v=4",
                "--stderrthreshold=info",
                "--cloud-provider=aws",
                "--skip-nodes-with-local-storage=false",
                "--expander=least-waste",
                "--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${var.cluster_name}",
                "--balance-similar-node-groups",
                "--skip-nodes-with-system-pods=false",
              ]
              "image"           = "registry.k8s.io/autoscaling/cluster-autoscaler:${var.cluster_autoscaler_version}"
              "imagePullPolicy" = "Always"
              "name"            = "cluster-autoscaler"
              "resources" = {
                "limits" = {
                  "cpu"    = "100m"
                  "memory" = "600Mi"
                }
                "requests" = {
                  "cpu"    = "100m"
                  "memory" = "600Mi"
                }
              }
              "volumeMounts" = [
                {
                  "mountPath" = "/etc/ssl/certs/ca-certificates.crt"
                  "name"      = "ssl-certs"
                  "readOnly"  = true
                },
              ]
            },
          ]
          "priorityClassName" = "system-cluster-critical"
          "securityContext" = {
            "fsGroup"      = 65534
            "runAsNonRoot" = true
            "runAsUser"    = 65534
          }
          "serviceAccountName" = "cluster-autoscaler"
          "volumes" = [
            {
              "hostPath" = {
                "path" = "/etc/ssl/certs/ca-certificates.crt"
              }
              "name" = "ssl-certs"
            },
          ]
        }
      }
    }
  }
}
