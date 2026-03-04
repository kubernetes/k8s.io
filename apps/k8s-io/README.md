Overview
====
This contains the routing configuration for k8s.io and the associated subdomain
redirectors. Traffic routing is implemented using the Kubernetes
[Gateway API](https://gateway-api.sigs.k8s.io/) (HTTPRoute resources) on GKE,
with an nginx backend for routes that require regex capture groups or backend
logic (go-get meta tags, proxying, static files).

Architecture
====

Traffic flows through GKE Gateway API resources:

```
Internet → GKE Gateway (gke-l7-global-external-managed) → HTTPRoute → nginx backend
```

- **`gateway-prod.yaml`**: Gateway resources for the `k8s-io-prod` namespace (IPv4 + IPv6).
  TLS is handled via a GCP Certificate Map (`k8s-io-cert-map`).
- **`gateway-canary.yaml`**: Gateway resources for the `k8s-io-canary` namespace (IPv4 + IPv6).
  TLS uses a cert-manager Certificate (`k8s-io-tls` secret).
- **`httproutes.yaml`**: HTTPRoute resources implementing all redirect logic.
  Applied per-environment via `deploy.sh` using `--namespace`.
- **`configmap-nginx.yaml`**: Minimal nginx config for routes requiring regex
  capture groups or backend functionality (go-get meta tags, proxying, static files).

Routes handled by HTTPRoute (no nginx needed):
- HTTP → HTTPS redirect for all hosts
- x-k8s.io → kubernetes.io
- blog.k8s.io → kubernetes.io/blog/*
- apt.k8s.io, yum.k8s.io → CDN redirects
- packages.k8s.io, pkgs.k8s.io → OBS CDN redirects
- changelog.k8s.io → GitHub CHANGELOG
- code.k8s.io → GitHub tree/master
- conduct.k8s.io → GitHub committee-code-of-conduct
- dl.kubernetes.io → dl.k8s.io (dl.k8s.io itself is served by Fastly CDN)
- feature.k8s.io, features.k8s.io → GitHub features/issues
- go.k8s.io → specific path redirects (fixed paths only)
- issue.k8s.io, issues.k8s.io → GitHub issues
- kep.k8s.io → GitHub enhancements/issues
- pr.k8s.io, prs.k8s.io → GitHub pull requests
- slack.k8s.io → communityinviter.com
- submit-queue.k8s.io → prow.k8s.io/tide
- yt.k8s.io, youtube.k8s.io → youtube.com

Routes handled by nginx backend:
- k8s.io go-get responses (HTML meta tags)
- sigs.k8s.io (go-get + path-depth-based GitHub routing)
- go.k8s.io /owners/$user, /contact/$group (regex capture groups)
- get.k8s.io (proxy to GitHub + static files)
- git.k8s.io (path-depth-based routing)
- docs.k8s.io (version prefix stripping)
- examples.k8s.io (version-specific routing)
- ci-test.k8s.io (directory vs file routing)
- releases.k8s.io, rel.k8s.io (version-specific routing)
- sbom.k8s.io (regex routing)

Vanity URL(s)
====

|  | k8s.io | kubernetes.io |
| --- | --- | --- |
| APT downloads| https://apt.k8s.io | https://apt.kubernetes.io |
| Blog | https://k8s.io/blog | https://kubernetes.io/blog |
| Changelog | https://changelog.k8s.io | https://changelog.kubernetes.io |
| CI logs | https://ci-test.k8s.io | https://ci-test.kubernetes.io |
| Git repo | https://code.k8s.io | https://code.kubernetes.io |
| Search Git repo | https://cs.k8s.io | https://cs.kubernetes.io |
| Downloads | https://dl.k8s.io | https://dl.kubernetes.io |
| Documentation | https://docs.k8s.io | https://docs.kubernetes.io |
| Kubernetes examples | https://examples.k8s.io | https://examples.kubernetes.io |
| Features repo | https://feature.k8s.io <br> https://features.k8s.io |  https://feature.kubernetes.io <br> https://features.kubernetes.io |
| Install script | https://get.k8s.io | https://get.kubernetes.io |
| Github organization| https://git.k8s.io | https://git.kubernetes.io |
| Redirections | https://go.k8s.io | https://go.kubernetes.io |
| Issues | https://issue.k8s.io <br> https://issues.k8s.io | https://issue.kubernetes.io <br> https://issues.kubernetes.io |
| Main site | https://k8s.io | https://kubernetes.io |
| Packages (OpenBuildService) | https://packages.k8s.io <br> https://pkgs.k8s.io | https://packages.kubernetes.io <br> https://pkgs.kubernetes.io |
| PR Dashboard | https://pr-test.k8s.io | https://pr-test.kubernetes.io |
| Pull requests | https://pr.k8s.io <br> https://prs.k8s.io | https://pr.kubernetes.io <br> https://prs.kubernetes.io |
| Downloads | https://releases.k8s.io <br> https://rel.k8s.io | https://releases.kubernetes.io <br> https://rel.kubernetes.io |
| Kubernetes SIGs | https://sigs.k8s.io | |
| Tide status (formerly submit queue) | https://prow.k8s.io/tide | https://prow.kubernetes.io/tide |
| TestGrid | https://testgrid.k8s.io | https://testgrid.kubernetes.io |
| YUM downloads | https://yum.k8s.io | https://yum.kubernetes.io |
| Kubernetes YouTube | https://yt.k8s.io | https://youtube.k8s.io | https://youtube.kubernetes.io | https://yt.kubernetes.io |

NOTE: please see k8s.io/k8s.io/configmap-nginx.yaml for `server` definitions

# Redirections

## go.k8s.io Redirects
- https://go.k8s.io/api-review
- https://go.k8s.io/bot-commands
- https://go.k8s.io/calendar
- https://go.k8s.io/github-labels
- https://go.k8s.io/good-first-issue
- https://go.k8s.io/help-wanted
- https://go.k8s.io/needs-ok-to-test
- https://go.k8s.io/oncall
- https://go.k8s.io/oncall-hotlist
- https://go.k8s.io/owners
- https://go.k8s.io/owners/${GITHUB_USER}
- https://go.k8s.io/partner-request
- https://go.k8s.io/pr-dashboard
- https://go.k8s.io/redirects
- https://go.k8s.io/sig-k8s-infra
- https://go.k8s.io/sig-k8s-infra-notes
- https://go.k8s.io/sig-k8s-infra-playlist
- https://go.k8s.io/start
- https://go.k8s.io/stuck-prs
- https://go.k8s.io/test-health
- https://go.k8s.io/test-history
- https://go.k8s.io/triage
- https://go.k8s.io/logo
- https://go.k8s.io/contact
- https://go.k8s.io/contact/${GROUP_NAME}
  - For example:
    - https://go.k8s.io/contact/sig-contributor-experience
    - https://go.k8s.io/contact/wg-lts
    - https://go.k8s.io/contact/committee-steering

## rel.k8s.io Redirects

### Direct Redirects
- https://rel.k8s.io/ → https://github.com/kubernetes/kubernetes/releases
- https://rel.k8s.io/release-team-cal → https://calendar.google.com/calendar/embed?src=agst.us_b07popf7t4avmt4km7eq5tk5ao%40group.calendar.google.com
- https://rel.k8s.io/k8s-sig-release-videos → https://youtube.com/playlist?list=PL69nYSiGNLP3QKkOsDsO6A0Y1rhgP84iZ&si=Mi095CYuJuz8LjN-

### Version-specific Redirects

Example:
- https://rel.k8s.io/vXYY
- https://rel.k8s.io/vX.YY
- https://rel.k8s.io/vXYY/releasemtg
- https://rel.k8s.io/vX.YY/releasemtg
- https://rel.k8s.io/vXYY/retro
- https://rel.k8s.io/v1XYY/contacts (Note: Access is restricted through Google Authorization)

For all release versions, URLs follow this pattern:
- https://rel.k8s.io/vXYY/{keyword} → https://github.com/kubernetes/sig-release/tree/master/releases/release-X.YY/links.md#{keyword}


NOTE: please see configmap-nginx.yaml for nginx rewrite rules (complex routes)
and httproutes.yaml for Gateway API HTTPRoute rules (simple redirects).

How to deploy
====

Gateway resources (one-time infrastructure setup, per environment):

```bash
kubectl --context gke_kubernetes-public_us-central1_aaa apply -f gateway-prod.yaml
kubectl --context gke_kubernetes-public_us-central1_aaa apply -f gateway-canary.yaml
```

**Note for prod**: A GCP Certificate Map named `k8s-io-cert-map` must exist in
the `kubernetes-public` project, covering the same domains listed in
`certificate-prod.yaml`. See
[Certificate Manager docs](https://cloud.google.com/certificate-manager/docs/overview).

Application deployment (run `./deploy.sh`):

1) Log into Google Cloud Shell.  Our clusters do not allow access from the
   internet.

2) Get the credentials for the cluster, if you don't already have them.  Run
   `gcloud container clusters get-credentials aaa --region us-central1
   --project kubernetes-public`.  When this is done, you should be able to list
   namespaces with `kubectl --context gke_kubernetes-public_us-central1_aaa get
   ns`.

3) Run `./deploy.sh`.  This will effectively run `./deploy.sh canary` to push
   and test configs in the canary namespace, followed by `./deploy.sh prod` to
   do the same in prod if tests pass against canary.
