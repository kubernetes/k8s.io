Please run this command to upgrade External Secret Secrets Operator:

```
helm template external-secrets \
   external-secrets/external-secrets  \
   -f=values \
   -n=external-secrets > external-secrets.yaml
```
