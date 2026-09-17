
# Kubernetes clusters owned by SIG K8s-Infra

This folder contains the declarative configuration for Kubernetes clusters managed by this repo.
The general pattern is:

- Per-cluster configuration lives in `kubernetes/<cluster-name>/...`.
- Shared workloads are defined as Argo CD Applications/ApplicationSets in `kubernetes/apps/`.
- Argo CD itself runs in the `gke-utility` cluster (see `kubernetes/gke-utility/argocd/`).

We use ArgoCD to manage our cluster, you can access it at argo.k8s.io, to access the app, you need to:
- be a member of the kubernetes github org
- add your github user to the AuthorizationPolicy in this file: `kubernetes/gke-utility/argocd/extras.yaml#L62`

[![App Status](https://argo.k8s.io/api/badge?name=apps&revision=true&showAppName=true)](https://argo.k8s.io/applications/apps)

## Clusters managed here

Cluster directories under `kubernetes/` correspond to the clusters Argo CD manages:

- `aks-prow-build` A Prow Build Cluster in AKS
- `eks-prow-build` A Prow Build Cluster in EKS
- `eks-prow-kops` A Prow Build Cluster in EKS
- `gke-aaa` A shared GKE cluster that runs our applications
- `gke-prow` Prow Control Plane Cluster on GKE
- `gke-prow-build` A Prow Build Cluster in GKE
- `gke-prow-build-trusted` A Prow Build Cluster in GKE, for trusted/sensitive jobs
- `gke-utility` A GKE cluster running utility workloads such as ArgoCD, Atlantis, Unified Monitoring Stack, etc
- `ibm-ppc64le` A Prow Build Cluster in IBM
- `ibm-s390x` A Prow Build Cluster in IBM

Cluster registration/labels used by ApplicationSets are defined in `kubernetes/gke-utility/argocd/clusters.yaml`.

## Workloads

This repo manages many workloads; common examples include:

- `prow` this contains all components of prow deployed in test-pods namespace for all build clusters.
- `datadog`, our monitoring, security tooling on all AKS/EKS/GKE clusters


### Note

- The `gke-aaa` kubernetes manifests are not being managed by ArgoCD yet, you can find them in the `apps` folder

## Updating Cluster Credentials

Most of our clusters use Workload Identity Federation and their kubeconfigs only change when the underlying cluster object is deleted, however the following clusters use client certificates for authentication:

- k8s-infra-ppc64le-prow-build
- k8s-infra-s390x-prow-build.

We store secrets in Google Cloud Secret Manager and there are 3 secrets that need to be populated.
- a secret that K8s Infra SREs and Cluster Operators have access to.
- a secret consumed by Prow directly which only K8s Infra SREs can access and write to.
- a secret consumed by ArgoCD that needs to be in a special format that K8s Infra SREs will generate.


In order to rotate their credentials, you must do the following:

### Helper utilities

1. Run the following commands before starting:
    ```sh
    rename-kube() {
        CTX="$1" yq -i '
        (.contexts[] | select(.name == strenv(CTX))) as $ctx |
        $ctx.context.cluster as $cluster |
        $ctx.context.user as $user |
        (.clusters[] | select(.name == $cluster) | .name) = strenv(PROW_CLUSTER_NAME) |
        (.users[] | select(.name == $user) | .name) = strenv(PROW_CLUSTER_NAME) |
        (.contexts[] | select(.name == strenv(CTX)) | .name) = strenv(PROW_CLUSTER_NAME)|
        (.contexts[] | select(.context.cluster == $cluster) | .context.cluster) = strenv(PROW_CLUSTER_NAME) |
        (.contexts[] | select(.context.user == $user) | .context.user) = strenv(PROW_CLUSTER_NAME) |
        .["current-context"] = strenv(PROW_CLUSTER_NAME)
    ' "${KUBECONFIG:-}"
    }

    kube-tls-json() {
        kubectl --context "${1:?context required}" config view --raw --flatten --minify -o json |
            jq '{
            tlsClientConfig: {
                insecure: (.clusters[0].cluster["insecure-skip-tls-verify"] // false),
                caData: (.clusters[0].cluster["certificate-authority-data"] // ""),
                CertData: (.users[0].user["client-certificate-data"] // ""),
                KeyData: (.users[0].user["client-key-data"] // "")
            }
        }'
    }
    ```

### k8s-infra-ppc64le-prow-build

1. Make sure the cluster operator is a member of the `k8s-infra-ibm-ppc64le-admins@kubernetes.io` Google Group
1. Use gcloud to add the kubeconfig to the secret `ppc64le-kubeconfig-external` [here](https://console.cloud.google.com/security/secret-manager/secret/ppc64le-kubeconfig-external/versions?project=k8s-infra-prow).
1. Ask someone from SIG K8s Infra Leads to run the remaining commands:
    1. Add the secrets for Prow:
        ```bash
        export KUBECONFIG=/tmp/kubeconfig
        gcloud secrets versions access latest --secret ppc64le-kubeconfig-external --project k8s-infra-prow > /tmp/kubeconfig
        kubectl get nodes # validate the cluster
        export PROW_CLUSTER_NAME=k8s-infra-ppc64le-prow-build # Note: this is the name of the cluster in prow
        rename-kube $(kubectl config current-context)
        gcloud secrets versions add k8s-infra-ppc64le-prow-build-kubeconfig --project k8s-infra-prow --data-file /tmp/kubeconfig
        ```
    1. Add the secrets for ArgoCD:
        ```bash
        kube-tls-json $(kubectl config current-context) | gcloud secrets versions add ibm-ppc64le-argo-secret --project k8s-infra-prow --data-file=-
        ```

### k8s-infra-s390x-prow-build

1. Make sure the cluster operator is a member of the `k8s-infra-ibm-s390x-admins@kubernetes.io` Google Group
1. Use gcloud to add the kubeconfig to the secret `s390x-kubeconfig-external` [here](https://console.cloud.google.com/security/secret-manager/secret/s390x-kubeconfig-external/versions?project=k8s-infra-prow).
`gcloud secrets versions add k8s-infra-s390x-prow-build-kubeconfig --project k8s-infra-prow --data-file /foo/bar`
1. Ask someone from SIG K8s Infra Leads to run the remaining commands:
    1. Add the secrets for Prow:
        ```bash
        export KUBECONFIG=/tmp/kubeconfig
        gcloud secrets versions access latest --secret s390x-kubeconfig-external --project k8s-infra-prow > /tmp/kubeconfig
        kubectl get nodes # validate the cluster
        export PROW_CLUSTER_NAME=k8s-infra-s390x-prow-build
        rename-kube $(kubectl config current-context)
        gcloud secrets versions add k8s-infra-s390x-prow-build-kubeconfig --project k8s-infra-prow --data-file /tmp/kubeconfig
        ```
    1. Add the secrets for ArgoCD:
        ```bash
        kube-tls-json $(kubectl config current-context) | gcloud secrets versions add ibm-s390x-argo-secret --project k8s-infra-prow --data-file=-
        ```
