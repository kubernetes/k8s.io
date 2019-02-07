To bootstrap (per the [cert-manager getting started
guide](https://cert-manager.readthedocs.io/en/release-0.6/getting-started/install.html#installing-with-regular-manifests)):

```
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)
kubectl apply -f cert-manager.yaml --validate=false  # --validate=false no longer needed with k8s 1.13+
kubectl apply -f letsencrypt-staging.yaml
kubectl apply -f letsencrypt-prod.yaml
```

This will set up cluster-wide webhooks and issuers, you can subsequently create
`Certificate` resources in other namespaces without repeating these steps.

Note that due to https://github.com/jetstack/cert-manager/issues/1343, you
should not add the `tls` field to the `Ingress` object until after the first
certificate has been issued.
