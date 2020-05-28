[node-perf-dash](https://github.com/kubernetes-retired/contrib/tree/master/node-perf-dash) is a web UI to collect and analyze performance test results of Kubernetes nodes. 

To bootstrap `node-perf-dash`:

```bash
for manifest in ./*.yaml; do
    kubectl apply -f "${manifest}"
done
```
