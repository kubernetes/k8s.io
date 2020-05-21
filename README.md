# k8s.io

Kubernetes files for various sites and infrastructure

- `audit`: script to dump all gcp resources to repo, and its most recently-reviewed results
- `cert-manager`: community-managed deployment of [cert-manager] for the `aaa` cluster
- `dns`: community-managed DNS for kubernetes.io and k8s.io
- `gcsweb.k8s.io`: community-managed deployment of [gcsweb]
- `groups`: community-managed google groups on the kubernetes.io domain
- `infra`: scripts/terraform files for community management of infra
- `k8s.gcr.io`: community-managed GCR repos
- `k8s.io`: community-managed deployment of nginx that provides redirects for k8s.io and its subdomains
- `perf-dash.k8s.io`: community-managed deployment of [perfdash]
- `publishing-bot`: community-managed deployment of [publishing-bot]
- `slack-infra`: community-managed deployment of [slack-infra]
- `node-perf-dash`: community-managed performance dashboard for Kubernetes node tests.

We provide a [publicly viewable billing-report][billing-report] accessible to members of [kubernetes-wg-k8s-infra@googlegroups.com]

Please see https://git.k8s.io/community/wg-k8s-infra for more information

[cert-manager]: https://github.com/jetstack/cert-manager
[gcsweb]: https://git.k8s.io/test-infra/gcsweb
[perfdash]: https://git.k8s.io/perf-tests/perfdash
[publishing-bot]: https://git.k8s.io/publishing-bot
[slack-infra]: https://sigs.k8s.io/slack-infra

[billing-report]: https://datastudio.google.com/u/0/reporting/14UWSuqD5ef9E4LnsCD9uJWTPv8MHOA3e
[kubernetes-wg-k8s-infra@]: https://groups.google.com/forum/#!forum/kubernetes-wg-k8s-infra
