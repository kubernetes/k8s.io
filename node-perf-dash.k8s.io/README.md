[node-perf-dash](https://github.com/kubernetes-retired/contrib/tree/master/node-perf-dash) is a web UI to collect and analyze performance test results of Kubernetes nodes. 

To bootstrap `node-perf-dash`:

```bash
kubectl apply -f certificate.yaml
kubectl apply -f deployment.yaml
kubectl apply -f ingress.yaml
kubectl apply -f service.yaml
```
