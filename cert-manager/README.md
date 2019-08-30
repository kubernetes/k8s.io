To bootstrap (per the [cert-manager getting started
guide](https://cert-manager.readthedocs.io/en/release-0.9/getting-started/install/kubernetes.html#installing-with-regular-manifests)):

```
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)
kubectl apply -f cert-manager.yaml --validate=false  # --validate=false no longer needed with k8s 1.13+
kubectl apply -f letsencrypt-staging.yaml
kubectl apply -f letsencrypt-prod.yaml
kubectl apply -f selfsigning-clusterissuer.yaml
```

This will set up cluster-wide webhooks and issuers, you can subsequently create
`Certificate` resources in other namespaces without repeating these steps.
