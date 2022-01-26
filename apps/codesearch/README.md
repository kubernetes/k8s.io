# Codesearch (Hound)

Hound is an extremely fast source code search engine. See some details here:
https://github.com/hound-search/hound/pkgs/container/hound

and the code here:
https://github.com/etsy/hound


## How to deploy codesearch

Deployment of codesearch is automatically triggered by prow when pull requests against `apps/codesearch` are merged.
Prow runs `./deploy.sh`. 

NOTE: hound takes a while to fetch data from github and only after that it starts listening on
the port 6080, so look at the logs to see if the endpoint has started. When it is done you will
see the following:

```
2021/09/15 22:42:01 All indexes built!                                                                                                                               │
2021/09/15 22:42:01 running server at http://localhost:6080
```

## How to debug codesearch 

Ensure you have [access to the cluster]

Ensure you are a member of `k8s-infra-rbac-codesearch@kubernetes.io`

[access to the cluster]: https://github.com/kubernetes/k8s.io/blob/main/running-in-community-clusters.md#access-the-cluster