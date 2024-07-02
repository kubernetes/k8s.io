# Kubecost installation on GKE cluster

> The secrets mentioned in the `helm-values` files were created on Google Secret Manager and added to the cluster with `external-secrets.yaml` file

The manifest were generated locally with below command:

```bash
helm template kubecost \
  --repo https://kubecost.github.io/cost-analyzer/ cost-analyzer \
  --version 2.0.1 \
  --namespace kubecost \
  --values ./helm-values
```
