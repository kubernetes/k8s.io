# Codesearch (Hound)

Hound is an extremely fast source code search engine. See some details here:
https://hub.docker.com/r/etsy/hound/

and the code here:
https://github.com/etsy/hound


## How to deploy codesearch

Deployment of codesearch is automatically triggered by prow when pull requests against `apps/codesearch` are merged.
Prow runs `./deploy.sh`. 

NOTE: hound takes a while to fetch data from github and only after that it starts listening on
the port 8080, so look at the logs to see if the endpoint has started. When it is done you will
see the following:

```
2017/12/15 14:55:58 All indexes built!
2017/12/15 14:55:58 running server at http://localhost:8080...
2017/12/15 15:02:01 Rebuilding kubernetes-bootcamp for af23e77ef9e90c4563d1a3bbb2c7313eec7ffb23
2017/12/15 15:02:01 merge 0 files + mem
2017/12/15 15:02:01 11802 data bytes, 35923 index bytes
```

## How to debug codesearch 

Ensure you have [access to the cluster]

Ensure you are a member of `k8s-infra-rbac-codesearch@kubernetes.io`

[access to the cluster]: https://github.com/kubernetes/k8s.io/blob/main/running-in-community-clusters.md#access-the-cluster