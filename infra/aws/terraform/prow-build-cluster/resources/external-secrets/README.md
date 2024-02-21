Please run this command to upgrade External Secret Secrets Operator:

```
helm template external-secrets \
   external-secrets/external-secrets  \
   -f=values \
   --version=0.9.13 \
   -n=external-secrets > external-secrets.yaml
```
