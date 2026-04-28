## Resizing volume

Make sure that storage class allows for volume expansion, otherwise enable that option:

```bash
kubectl patch sc gp2 -p '{"allowVolumeExpansion": true}'
```

Next follow instructions from [resizing volumes section of prometheus operator docs](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/user-guides/storage.md#resizing-volumes):

```bash
kubectl patch prometheus/main --patch '{"spec": {"paused": true, "storage": {"volumeClaimTemplate": {"spec": {"resources": {"requests": {"storage":"300Gi"}}}}}}}' --type merge
```

```bash
for p in $(kubectl get pvc -l operator.prometheus.io/name=main -o jsonpath='{range .items[*]}{.metadata.name} {end}'); do \
  kubectl patch pvc/${p} --patch '{"spec": {"resources": {"requests": {"storage":"300Gi"}}}}'; \
done
```

```bash
kubectl delete statefulset -l operator.prometheus.io/name=main --cascade=orphan
```

```bash
kubectl patch prometheus/main --patch '{"spec": {"paused": false}}' --type merge
```
