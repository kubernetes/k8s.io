---
name: DNS Update Request
about: Request a create, delete or update of a kubernetes.io or k8s.io DNS record
title: 'DNS REQUEST: <your-dns-record>'
labels: wg/k8s-infra
assignees: ''

---

### Type of DNS update:
one of: Create, Delete, Update

### Domain being modified:
e.g. `k8s.io`

### Existing DNS Record:

```yaml
# this is the sub-domain, '' for the top-level domain
www:
# this is the record type, e.g A, CNAME, MX, TXT, etc.
- type: A
  # This depends on the record type, see existing YAML files for more examples.
  value: 23.236.58.218
```

### New DNS Record:

```yaml
www:
- type: CNAME
  value: some.other.host.com
```

### Reason for update:

Example of an update.
