# How to run your thing in our cluster(s)

As a community, we run a number of services.  This ranges from
developer-oriented stuff like CI and dashboards to user-facing stuff like
k8s.io and the various shortcut names.

This document aims to explain how you can run something, too.

## Where are the clusters?

At the time of this writing we have one cluster, called "aaa" running in GKE.
We will expand that as and when needed.

## What can I run?

Whatever you run has to be legitimately community-property and has to be
"reasonable".  These are not free resources, but we're also not trying to
stifle good work.  We typically think about this in terms of web-services, but
that is not necessarily all people will run.  Over time we expect the diversity
of workloads to increase.

## How to reach the cluster-admins

Your escape hatch at every step is to reach out to the kubernetes community
cluster-admins.  You can email k8s-infra-cluster-admins@kubernetes.io or find
many of us in the #wg-k8s-infra Slack channel.

## Prep a Pull Request against this repo

You can include all of these steps in a single PR.

### Decide which namespace name(s) you want

You will get one or more namespaces to run your thing.  Decide what names you
want and make sure they are available.  Check the list in [the namespaces
config](/infra/gcp/namespaces/ensure-namespaces.sh), and add your names there.
Keep them short but descriptive.

### Create a google-group for each namespace

Add a block to [groups.yaml](/groups/groups.yaml) for each namespace you want.  Each group
should be named `k8s-infra-rbac-<namespace>`.

Add the approriate set of users to these groups.  Keep it as small as possible,
but make sure there are enough to people to keep it running.  If you have
multiple namespaces that should be kept in sync, say so in the description.

Add these new groups to the group called "gke-security-groups", which will
enable the RBAC linkage.

Finally, add the groups as regular expressions to the `path: "groups.yaml"`
section of [restrictions.yaml](/groups/restrictions.yaml).

### Send your PR

Once reviewed and merged, one of the group admins will create the
google-group(s) you requested.  Then a cluster admin will make your
namespace(s) and install the RBAC rules for you.

At this point, any members of the "rbac" group(s) should be able to access the
cluster.

## Access the cluster

To access our clusters, you will need to use Google's [Cloud
Shell](https://ssh.cloud.google.com/cloudshell).  If you need to inspect more
of the infrastructure, you can use Google's [Cloud
Console](https://console.cloud.google.com/kubernetes/clusters/details/us-central1/aaa?project=kubernetes-public).

The first time you use this, you must get credentials for the cluster.  From your CloudShell prompt, run:

```sh
gcloud container clusters get-credentials aaa --project kubernetes-public --region=us-central1
```

You might want to abbreviate the context:

```sh
kubectl config rename-context gke_kubernetes-public_us-central1_aaa prod-aaa
```

Once that is done, you should be able to run `kubectl` against the cluster:

```
$ kubectl --context=prod-aaa get ns
NAME             STATUS   AGE
cert-manager     Active   121d
default          Active   155d
```

## Configure your workload

You can now run Deployments and expose Services and so on.

### Public IPs

You are allowed to create Ingresses and Services with public IPs.  Before you are done
configuring your thing, you probably want your IPs to be earmarked as
"static".  This ensures that you can keep the same IP if you ever need to
recreate your Service or Ingress.  To do that, ask one of the cluster-admins to
do it manually.  Then you can configure your Service or Ingress to reference it
explicitly.

### DNS

If you are exposing a public IP, you probably want DNS for it.  You can send a
PR against [the DNS config](/dns/zone-configs/) to add or update your name.

### TLS

If you are exposing a public IP, you *must* do so securely.  For HTTP, this
means TLS.  We run [cert-manager](/cert-manager) in the cluster(s), so you can
simply create a `Certificate` object.  See the examples in this repo.

### Secrets

Your RBAC access does not include the ability to create arbitrary `Secrets`.
If you need to do that, talk to cluster-admins.

## Configure monitoring and alerting

Coming soon.  This is not yet fully decided.

## Be responsible

It is your responsibility to keep your workloads running and secure, and to use
resources responsibly.  The cluster-admins team will provide some basic
oversight (which will get better over time), but you are the front-line for
your app.
