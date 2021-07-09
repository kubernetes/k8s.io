# apps

Kubernetes community-managed project infrastructure in the form of apps that
run on the `aaa` cluster. See [running-in-community-clusters.md] for more details

## proposed format

Each directory in here corresponds to a single `app`, which means:

- the app runs in a namespace named `app` on the `aaa` cluster
- the app is owned by a SIG, as designated by a `sig/foo` label in OWNERS
- app managers are members of the `k8s-infra-rbac-{app}@kubernetes.io` group
- the app's k8s resources all have the label `app: {app}`
- any secrets needed by this app are implemented via `ExternalSecret` CRDs (TODO(https://github.com/kubernetes/k8s.io/issues/2220))

The expected layout for a given app is:

```
{app}               # the k8s namespace this runs in, managed by k8s-infra-rbac-{app}@kubernetes.io
    ├── OWNERS      # must have relevant reviewers/approvers, and labels: [sig/foo, area/apps/{app}]
    ├── README.md   # what is it, who owns it, how to deploy it
    ├── deploy.sh   # ideally "how to deploy it" == run this script
    └── *.yaml      # kubernetes resources / manifests, deployable via kubectl apply -f
```

Expect this to change as we iterate toward convergence on a standard that
actually fits the apps we run today.

## known issues

- enforcement
    - OWNER constraints enforcemed by humans
    - no validation of yaml beyond yamllint
    - `app:` convention enforcement by humans
- `*.yaml` can be more than k8s resources
    - consider a `resources/` subdir convention for all k8s resources
    - allows for config files etc. at app root
- `app:` label convention
    - cert-manager has multiple `app:` labels: `cainjector`, `cert-manager`, `webhook`, and many empty
    - consider a custom label `k8s-infra-app:`; could do prefix but then need to decide on a DNS name
    - is this a convention worth enforcing? perhaps namespace is enough

[running-in-community-clusters.md]: /running-in-community-clusters.md
