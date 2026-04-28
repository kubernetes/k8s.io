# Managing DNS for Kubernetes domains

## Zones

Zones we manage:
  - kubernetes.io
  - k8s.io
  - x-k8s.io
  - k8s-e2e.com
  - kubernetes.dev
  - k8s.dev
  - etcd.io

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
([job `post-k8sio-dns`](https://github.com/kubernetes/test-infra/blob/2b748fdf2a157abded6b74288c7c8f9642eca85e/config/jobs/kubernetes/sig-k8s-infra/trusted/sig-k8s-infra-dns.yaml#L3-L31))
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

## How to add a new domain

1. If the domain has existing records, be sure to acquire a copy of the existing zone.
1. Modify the `dns/octodns-config.yaml` file to include the new domain, including the canary subdomain.
1. In the "Cloud DNS" panel of the `kubernetes-public` project, create two zones: one for the actual domain, and one for the canary subdomain.
1. Create the zone files in the `dns/zone-configs` directory:
  1. The $domain._0_base.yaml file should contain all the records for the domain, *except* the NS and SOA records.
  1. The $domain._1_canary.yaml file should contain the NS records for the canary subdomain only, as provided by Google.
  1. The canary.$domain.yaml file should be a symlink to the $domain._0_base.yaml file
1. Update the prod zones lists in both the `dns/Makefile` and `dns/push.sh` files.
1. Once merged, the domain should now be managed. The first run may fail due to propagation delays, but subsequent runs should succeed.
1. After the records are verified as being pushed to the zones in the `kubernetes-public` project, the nameservers can be updated with the registrar (typically LF IT).

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
