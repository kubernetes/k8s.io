Please run this command to upgrade Kyverno:

```
helm template kyverno \
    kyverno/kyverno \
    -f=values \
    -n=kyverno > kyverno.yaml
```

`helm template` does not properly template api resource versions, thus **PodDisruptionBudget** api version must be changed from `policy/v1beta1` to `policy/v1` after running the previous command.
