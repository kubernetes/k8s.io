To bootstrap [Perfdash](https://github.com/kubernetes/perf-tests/tree/master/perfdash):

```bash
PERFDASH_REPO_URL="https://raw.githubusercontent.com/kubernetes/perf-tests/master/perfdash"
PERFDASH_NAMESPACE="perfdash"

kubectl apply -n "$PERFDASH_NAMESPACE" -f "${PERFDASH_REPO_URL}/deployment.yaml"
kubectl apply -n "$PERFDASH_NAMESPACE" -f "${PERFDASH_REPO_URL}/perfdash-service.yaml"

kubectl apply -n "$PERFDASH_NAMESPACE" -f ingress.yaml
kubectl apply -n "$PERFDASH_NAMESPACE" -f certificate.yaml
```
