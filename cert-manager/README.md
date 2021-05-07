# Introduction

[cert-manager](cert-manager.io) is used to manage the certificates from 
k8s.io infrastructure, mainly from the websites provided via
Ingress objects.

This repository contains the files used to bootstrap cert-manager on 
infrastructure cluster. This deploy nowadays is done manually, but this can be
changed and automatized in the future

# Generating the files

Cert-manager provides a file containing all the necessary objects to be created 
in a Kubernetes cluster to make it work.

Because of the amount of CRDs and other objects, this files might have more than 
20k lines, turning a single review of an update really hard. So this manifest is 
split into cluster and namespace objects.

To split this files, the tool [manifest-splitter](https://github.com/munnerz/manifest-splitter) 
can be used as following (assuming you've downloaded the manifest-splitter 
code and are inside the source directory):

```
go run . --kubeconfig $HOME/.kube/config --output=/path/to/output/dir /path/to/cert-manager.yaml
```

This will generate two directories:
* namespaces - Contains objects that are not cluster scoped
* cluster - contains cluster scoped objects

# Installing

To install cert-manager, just do a `kubectl apply -f` into the generated 
directories:

```
kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)
kubectl apply -f ./cluster
kubectl apply -f ./namespaces
```

After that, you can proceed (if you didn't already) to the creation of the `ClusterIssuer` objects:
```
kubectl apply -f letsencrypt-staging.yaml
kubectl apply -f letsencrypt-prod.yaml
kubectl apply -f selfsigning-clusterissuer.yaml
```

This will set up cluster-wide webhooks and issuers, you can subsequently create
`Certificate` resources in other namespaces without repeating these steps.
