# k8s.io

Kubernetes project infrastructure, managed by the kubernetes community via [sig-k8s-infra]

- `apps`: community-managed apps that run on the community-managed `aaa` cluster
    - `codesearch`: instance of [codesearch] at https://cs-canary.k8s.io - owned by [sig-k8s-infra]
    - `elekto`: instance of [elekto] at https://elections.k8s.io - owned by Elections officers (on behalf of [sig-contributor-experience])
    - `gcsweb`: instance of [gcsweb] at https://gcsweb.k8s.io - owned by [sig-testing]
    - `k8s.io`: instance of nginx that provides redirects/reverse-proxying for k8s.io and its subdomains - owned by [sig-contributor-experience] and [sig-testing]
    - `kubernetes-external-secrets`: instance of [kubernetes-external-secrets] - owned by [sig-testing]
    - `perfdash`: instance of [perfdash] - owned by [sig-scalability]
    - `prow`: work-in-progress instance of [prow] - owned by [sig-testing]
    - `publishing-bot`: instance of [publishing-bot] - owned by [sig-release]
    - `sippy`: instance of [sippy] at https://sippy.k8s.io - owned by [sig-architecture] (on behalf of [wg-reliability])
    - `slack-infra`: instance of [slack-infra] including https://slack.k8s.io - owned by [sig-contributor-experience]
    - `triageparty-cli`: instance of [triage-party] - owned by [sig-cli]
    - `triageparty-release`: instance of [triage-party] - owned by [sig-release]
- `audit`: scripts to export all relevant gcp resources, and the most recently-reviewed export
- `dns`: DNS for kubernetes.io and k8s.io
- `groups`: google groups on the kubernetes.io domain
- `hack`: scripts used for development, testing, etc.
- `images`: container images published to `gcr.io/k8s-staging-infra-tools`
- `infra/gcp`: scripts and data to manage our GCP infrastructure
    - `bash/namespaces`: scripts and data to manage K8s namespaces and RBAC for `aaa`
    - `bash/prow`: scripts and data used to manage projects used for e2e testing and managed by boskos
    - `bash/roles`: scripts and data to manage custom GCP IAM roles
    - `terraform/modules`: terraform modules intended for re-use within this repo
    - `terraform/projects`: terraform to manage (parts of) GCP projects
- `k8s.gcr.io`: container images published by the project, promoted from `gcr.io/k8s-staging-*` repos
- `policy`: [open policy agent][opa] policies used by [conftest] to validate resources in this repo
- `registry.k8s.io`: work-in-progress to support cross-cloud mirroring/hosting of containers and binaries

TODO: are these actively in use or should they be retired?
- `artifacts`
- `artifactserver`

We provide a [publicly viewable billing report][billing-report] accessible to members of [kubernetes-sig-k8s-infra@googlegroups.com][mailing-list]

Please see https://git.k8s.io/community/sig-k8s-infra for more information

<!-- apps -->
[cert-manager]: https://github.com/jetstack/cert-manager
[codesearch]: https://cs-canary.k8s.io
[elekto]: https://elekto.dev/
[gcsweb]: https://git.k8s.io/test-infra/gcsweb
[kubernetes-external-secrets]: https://github.com/external-secrets/kubernetes-external-secrets
[perfdash]: https://git.k8s.io/perf-tests/perfdash
[prow]: https://git.k8s.io/test-infra/prow
[publishing-bot]: https://git.k8s.io/publishing-bot
[sippy]: https://github.com/openshift/sippy
[slack-infra]: https://sigs.k8s.io/slack-infra
[triage-party]: https://github.com/google/triage-party

<!-- misc -->
[billing-report]: https://datastudio.google.com/u/0/reporting/14UWSuqD5ef9E4LnsCD9uJWTPv8MHOA3e
[opa]: https://www.openpolicyagent.org
[conftest]: https://www.conftest.dev
[mailing-list]: https://groups.google.com/g/kubernetes-sig-k8s-infra

<!-- community groups -->
[sig-architecture]: https://git.k8s.io/community/sig-architecture
[sig-cli]: https://git.k8s.io/community/sig-cli
[sig-contributor-experience]: https://git.k8s.io/community/sig-contributor-experience
[sig-k8s-infra]: https://git.k8s.io/community/sig-k8s-infra
[sig-node]: https://git.k8s.io/community/sig-node
[sig-release]: https://git.k8s.io/community/sig-release
[sig-scalability]: https://git.k8s.io/community/sig-scalability
[sig-testing]: https://git.k8s.io/community/sig-testing
[wg-reliability]: https://git.k8s.io/community/wg-reliability
