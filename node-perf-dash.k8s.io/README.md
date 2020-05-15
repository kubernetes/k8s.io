[node-perf-dash](https://github.com/kubernetes-retired/contrib/tree/master/node-perf-dash) is a web UI to collect and analyze performance test results of Kubernetes nodes. 

To bootstrap `node-perf-dash`:

```bash
kubectl apply -f node-perf-dash-certificate.yaml
kubectl apply -f node-perf-dash-deployment.yaml
kubectl apply -f node-perf-dash-ingress.yaml
kubectl apply -f node-perf-dash-service.yaml
```