# EKS monitoring

## Setting up monitoring

```bash
# Create monitoring namespace:
kubectl apply -f ../namespaces.yaml

# Install CRDs for Prometheus Operator:
# (server side is required due to long annotations)
kubectl apply --server-side -f ./prometheus-operator-crds

# Install Prometheus Operator:
kubectl apply  -f ./prometheus-operator

# Install kube-state-metrics
kubectl apply -f ./kube-state-metrics

# Install node-exporter
kubectl apply -f ./node-exporter

# Install dashboards for Grafana
kubectl apply --server-side -f ./grafana/dashboards

# Install Grafana
kubectl apply -f ./grafana
```

[Prometheus Operator CRDs](https://github.com/prometheus-operator/prometheus-operator/tree/v0.63.0/example/prometheus-operator-crd-full)

## Local access

```bash
# Prometheus
kubectl --namespace monitoring port-forward svc/prometheus-operated 9090

# Grafana
kubectl --namespace monitoring port-forward svc/grafana 3000
```

## Debugging

- [Troubleshooting Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/troubleshooting.md)

Checking Prometheus configuration:
```
kubectl -n monitoring get secret prometheus-main -ojson | jq -r '.data["prometheus.yaml.gz"]' | base64 -d | gunzip | less
```
