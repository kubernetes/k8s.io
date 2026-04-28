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

resource "kubernetes_cluster_role" "aggregated_metrics" {
  metadata {
    name = "system:aggregated-metrics-reader"
    labels = {
      "rbac.authorization.k8s.io/aggregate-to-view"  = "true"
      "rbac.authorization.k8s.io/aggregate-to-edit"  = "true"
      "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
    }
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "auth" {
  metadata {
    name = "metrics-server:system:auth-delegator"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.metrics.metadata[0].name
    namespace = kubernetes_service_account.metrics.metadata[0].namespace
  }
}

resource "kubernetes_role_binding" "auth" {
  metadata {
    name      = "metrics-server-auth-reader"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "extension-apiserver-authentication-reader"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.metrics.metadata[0].name
    namespace = kubernetes_service_account.metrics.metadata[0].namespace
  }
}

resource "kubernetes_cluster_role" "resource" {
  metadata {
    name = "system:metrics-server"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/metrics"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "resource" {
  metadata {
    name = "system:metrics-server"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.resource.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.metrics.metadata[0].name
    namespace = kubernetes_service_account.metrics.metadata[0].namespace
  }
}

resource "kubernetes_service_account" "metrics" {
  metadata {
    namespace = "kube-system"
    name      = "metrics-server"
  }
}

resource "kubernetes_api_service" "metrics" {
  metadata {
    name = "v1beta1.metrics.k8s.io"
  }

  spec {
    service {
      name      = "metrics-server"
      namespace = "kube-system"
    }

    group                    = "metrics.k8s.io"
    group_priority_minimum   = 100
    insecure_skip_tls_verify = true
    version                  = "v1beta1"
    version_priority         = 100
  }
}

resource "kubernetes_deployment" "metrics" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"

    labels = {
      "k8s-app" : "metrics-server"
    }
  }

  spec {
    selector {
      match_labels = {
        "k8s-app" : "metrics-server"
      }
    }

    template {
      metadata {
        name = "metrics-server"
        labels = {
          "k8s-app" = "metrics-server"
        }
      }

      spec {
        automount_service_account_token = true
        service_account_name            = kubernetes_service_account.metrics.metadata[0].name
        priority_class_name             = "system-cluster-critical"

        container {
          name              = "metrics-server"
          image             = "registry.k8s.io/metrics-server/metrics-server:v0.6.4"
          image_pull_policy = "IfNotPresent"
          args = [
            "--cert-dir=/tmp",
            "--secure-port=10250",
            "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
            "--kubelet-use-node-status-port",
            "--metric-resolution=15s"
          ]

          security_context {
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 1000
            allow_privilege_escalation = false
          }

          port {
            name           = "https"
            container_port = 10250
            protocol       = "TCP"
          }

          volume_mount {
            name       = "tmp-dir"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp-dir"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "metrics" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"

    labels = {
      "kubernetes.io/name"            = "metrics-server"
      "kubernetes.io/cluster-service" = "true"
    }
  }

  spec {
    selector = {
      "k8s-app" = "metrics-server"
    }

    port {
      name        = "https"
      port        = 443
      protocol    = "TCP"
      target_port = "https"
    }
  }
}
