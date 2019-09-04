Overview
====
This contains the TXTDirect configuration for the redirector.k8s.io backend service.

Currently used by:
- go.k8s.io
- go.kubernetes.io

Redirects are configured using DNS TXT records.
See /k8s.io/dns/go.k8s.io.yaml for current records.

The deployment consists of TXTDirect and a CoreDNS sidecar used for caching to make redirects much faster.
CoreDNS pushes non cached requests to Google DNS (8.8.8.8).

TXTDirect and CoreDNS export Prometheus metrics see the configmap for specific configuration.

Default redirects:
Non existent redirects will redirect to kubernetes.io as set within the configmap using the config value `redirect`.
