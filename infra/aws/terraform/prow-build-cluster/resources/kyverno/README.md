Please run this command to upgrade Kyverno:

```
helm template kyverno \
    kyverno/kyverno \
    -f=values \
    -n=kyverno > kyverno.yaml
```