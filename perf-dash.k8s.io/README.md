To bootstrap [Perfdash](https://github.com/kubernetes/perf-tests/tree/master/perfdash):

```bash
kubectl apply -f certificate.yaml
kubectl apply -f deployment.yaml
kubectl apply -f ingress.yaml
kubectl apply -f service.yaml
```
