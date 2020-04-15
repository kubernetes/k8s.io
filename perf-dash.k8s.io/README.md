To bootstrap [Perfdash](https://github.com/kubernetes/perf-tests/tree/master/perfdash):

```bash
PERFDASH_REPO_URL="https://raw.githubusercontent.com/kubernetes/perf-tests/master/perfdash"
PERFDASH_MANIFEST_URL_DEPLOYMENT="${PERFDASH_REPO_URL}/deployment.yaml"
PERFDASH_MANIFEST_URL_SERVICE="${PERFDASH_REPO_URL}/perfdash-service.yaml"
PERFDASH_NAMESPACE="perfdash"

kubectl apply -n "$PERFDASH_NAMESPACE" -f "$PERFDASH_MANIFEST_URL_DEPLOYMENT"
# There is no need to create LoadBalancer. When perf-dash will be
# fully deployed on the "aaa" cluster we'll change the type of service
# persistently in the source repository
curl "$PERFDASH_MANIFEST_URL_SERVICE" \
    | sed "s/type: LoadBalancer/type: NodePort/" \
    | kubectl apply -n "$PERFDASH_NAMESPACE" -f -

kubectl apply -n "$PERFDASH_NAMESPACE" -f ingress.yaml
kubectl apply -n "$PERFDASH_NAMESPACE" -f certificate.yaml
```
