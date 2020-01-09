Overview
====
This contains the Nginx configuration for k8s.io and the associated subdomain
redirectors.

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
| PR Dashboard | https://pr-test.k8s.io | https://pr-test.kubernetes.io |
| Pull requests | https://pr.k8s.io <br> https://prs.k8s.io | https://pr.kubernetes.io <br> https://prs.kubernetes.io |
| Downloads | https://releases.k8s.io <br> https://rel.k8s.io | https://releases.kubernetes.io <br> https://rel.kubernetes.io |
| Kubernetes SIGs | https://sigs.k8s.io | |
| Tide status (formerly submit queue) | https://prow.k8s.io/tide | https://prow.kubernetes.io/tide |
| TestGrid | https://testgrid.k8s.io | https://testgrid.kubernetes.io |
| YUM downloads | https://yum.k8s.io | https://yum.kubernetes.io |
| Kubernetes YouTube | https://yt.k8s.io | https://youtube.k8s.io | https://youtube.kubernetes.io | https://yt.kubernetes.io |

NOTE: please see k8s.io/k8s.io/configmap-nginx.yaml for `server` definitions

Redirections
====
- https://go.k8s.io/api-review
- https://go.k8s.io/bot-commands
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
- https://go.k8s.io/start
- https://go.k8s.io/stuck-prs
- https://go.k8s.io/test-health
- https://go.k8s.io/test-history
- https://go.k8s.io/triage
- https://go.k8s.io/youtube
- https://go.k8s.io/yt

NOTE: please see configmap-nginx.yaml for rewrite rules.

Testing
====
Configure kubectl to target a test cluster on GKE.

Run `make deploy-fake-secret deploy` and wait for the service to be available--
the load balancer may take some time to configure.

Set `TARGET_IP` to the ingress IP of the running service:

    export TARGET_IP=$(kubectl get svc k8s-io '--template={{range .status.loadBalancer.ingress}}{{.ip}}{{end}}')

Use `make test` to run unit tests to verify the various endpoints on the server.

Deploying
===
Set kubectl to target the production cluster, then run `make deploy`.

Publishing-bot
===

Details about running the [publishing-bot](https://git.k8s.io/publishing-bot)
for the Kubernetes project can be found
[here](https://git.k8s.io/publishing-bot/k8s-publishing-bot.md).
