# Managing DNS for Kubernetes domains

## Status

WIP.  The zones are created and have been synced once for testing, but none of
the rest of this is finalized.  Top-level NS records have not been flipped.

## Zones

Zones we manage:
  - kubernetes.io
  - k8s.io

## How to become an admin

Admin access is granted via
[googlegroups](https://groups.google.com/forum/#!forum/k8s-infra-dns-admins).

You must have a Google account that will let you access the Google Cloud
Console.

To volunteer for this effort, contact the main
[k8s-infra-team](https://groups.google.com/forum/#!forum/k8s-infra-team).

## Where is it hosted?

We host it in Google Cloud DNS.
  * GCP org = kubernetes.io
  * GCP project = kubernetes-public
  * https://console.cloud.google.com/net-services/dns/zones?project=kubernetes-public&organizationId=758905017065

## Requesting a DNS update

The process for requesting an update uses Github Issues and PRs.

### Update Request Issue

Open a new issue on this repository with the title "DNS Update Request"

In the issue, please list the following details:
   * If this update is a create, delete or update.
   * The base domain that is being modified (e.g. "k8s.io")
   * The complete data for the existing DNS record if applicable (Updates, Deletes).
   * The complete data for the new DNS record if applicable (Creates, Updates).
   * The reason for the update.

Once this issue is created, it should be acknowledged by a DNS administrator.

To open an issue for a DNS update please use the [template here](https://github.com/kubernetes/k8s.io/issues/new?template=dns-request.md)

### Example update issue content:

*Type of update:* Update

*Domain being modified:* `k8s.io`

*Existing DNS Record:*

```yaml
# this is the sub-domain, '' for the top-level domain
www:
# this is the record type, e.g A, CNAME, MX, TXT, etc.
- type: A
  # This depends on the record type, see existing YAML files for more examples.
  value: 23.236.58.218
```

*New DNS Record:*
```yaml
www:
- type: CNAME
  value: some.other.host.com
```

*Reason for update:*

Example of an update.

### Performing an update

#### Update Pull Request
First, the DNS adminstrator opens a PR with the requested update applied to the appropriate YAML file.
Next, the requestor validates that the PR looks correct for their request and responds `/lgtm`

The DNS adminstrator merges the PR once it has been LGTM'd

#### Applying the update
The DNS adminstrator applies the update using the instructions below. Once the update has been
applied, the DNS adminstrator closes the issue.

Note that in the future, we hope to automate this update so that it happens in response to the
merge of the update PR.

## How to update

We use [OctoDNS](https://github.com/github/octodns) to manage the live config.
Eventually we want this automated and triggered by git commits.  Until then,
manual runs are OK.

### Docker image

From this repo:

```
docker build -t ${USER}/octodns ./octodns-docker
```

### Running as yourself

If you want to run it as yourself, using yor own Google Cloud credentials:

```
# Assumes to be running in a checked-out git repo directory, and in the same
# subdirectory as this file.
docker run -ti \
    -u `id -u` \
    -v ~/.config/gcloud:/.config/gcloud:ro \
    -v `pwd`/zone-configs:/octodns/config:ro \
    -v `pwd`/octodns-config.yaml:/octodns/config.yaml:ro \
    ${USER}/octodns \
    octodns-sync \
        --config-file=/octodns/config.yaml \
        --log-stream-stdout \
        --debug \
        --doit # leave this off if you want to do a dry-run
```

### Running automated

To run it automated (with GCP service account creds), get the JSON for the
service account, edit octodns-config.yaml and un-comment the `credentials_file`.


```
# Assumes to be running in a checked-out git repo directory, and in the same
# subdirectory as this file.
docker run -ti \
    -v `pwd`/zone-configs:/octodns/config \
    -v `pwd`/octodns-dns-admin-creds.json:/octodns/creds/gcp.json \
    -v `pwd`/octodns-config.yaml:/octodns/config.yaml \
    ${USER}/octodns \
    octodns-sync \
        --config-file=/octodns/config.yaml \
        --log-stream-stdout \
        --debug \
        --doit # leave this off if you want to do a dry-run
```

## TODO

Administrative:
  * Document how to handle "too many" updates (--force)
    * Always --force?
  * Billing report
  * Usage report
  * Monitoring / alerts / on-call for DNS?

How to automate:
  * Need a k8s cluster to run it
  * PR to github, cronjob in a cluster syncs
  * PR to github, manually apply a configmap, inotify/poll in a deployment
  * PR to github, webhook triggers run in a cluster
  * How to handle "too many updates"?
    * manual intervention?
    * always --force?
  * Push an official image to GCR
    * When to rebuild?

DNS content fixes:
  * Get owner names and comments on all records
  * Can we just have a * -> redirect.k8s.io as a catchall?
    * PRO: less rules overall, less churn
    * CON: any rando URL will now land somewhere (we could make them 404, maybe?)
  * Fix dl.k8s.io -> gcsweb or something useful
