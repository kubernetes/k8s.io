# Managing DNS for Kubernetes domains

## Zones

Zones we manage:
  - kubernetes.io
  - k8s.io
  - x-k8s.io
  - k8s-e2e.com
  - kubernetes.dev
  - k8s.dev

## How to become an admin

Admin access is granted via
[googlegroups](https://groups.google.com/a/kubernetes.io/forum/#!forum/k8s-infra-dns-admins).

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
  value: 35.201.71.162
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

First, the DNS administrator opens a PR with the requested update applied to the appropriate YAML file.
Next, the requestor validates that the PR looks correct for their request and responds `/lgtm`

The DNS administrator merges the PR once it has been LGTM'd

#### Applying the update

The update will be processed by
[prow](https://github.com/kubernetes/test-infra/tree/master/prow)
([job `post-k8sio-dns-update`](https://github.com/kubernetes/test-infra/blob/9ff09c1cc31965de97a1ed9b44cc7a1111406e19/config/jobs/kubernetes/wg-k8s-infra/trusted/wg-k8s-infra-trusted.yaml#L48-L68))
and will start automatically after Pull Request will be merged. Once the
update has been applied, the DNS administrator closes the issue.

## How to update manually

We use [OctoDNS](https://github.com/github/octodns) to manage the live config.

### Docker image

From this repo:

```
make build
```

### Running as yourself

If you want to run it as yourself, using your own Google Cloud credentials:

```
# Check all zones to ensure they are up to date:
make check
# Push all zones:
make push
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

DNS content fixes:
  * Get owner names and comments on all records
  * Can we just have a * -> redirect.k8s.io as a catchall?
    * PRO: less rules overall, less churn
    * CON: any random URL will now land somewhere (we could make them
      404, maybe?)
  * Fix dl.k8s.io -> gcsweb or something useful
