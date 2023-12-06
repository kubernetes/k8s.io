Overview
====
This contains the Nginx configuration for apt.k8s.io and yum.k8s.io
redirectors.

Vanity URL(s)
====

|  | k8s.io | kubernetes.io |
| --- | --- | --- |
| APT downloads| https://apt.k8s.io | https://apt.kubernetes.io |
| Kubernetes YouTube | https://yt.k8s.io | https://youtube.k8s.io | https://youtube.kubernetes.io | https://yt.kubernetes.io |

How to deploy
====

1) Log into Google Cloud Shell.  Our clusters do not allow access from the
   internet.

2) Get the credentials for the cluster, if you don't already have them.  Run
   `gcloud container clusters get-credentials aaa --region us-central1
   --project kubernetes-public`.  When this is done, you should be able to list
   namespaces with `kubectl --context gke_kubernetes-public_us-central1_aaa get
   ns`.

3) Run `./deploy.sh`.  This will effectively run `./deploy.sh canary` to push
   and test configs in the canary namespace, followed by `./deploy.sh prod` to
   do the same in prod if tests pass against canary.
