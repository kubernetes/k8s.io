# Auditing Configuration and Usage of Community Assets

## Status

WIP. Members of k8s-infra-gcp-auditors should be able to run this script to submit an audit PR. 

## How to become an auditor

Admin access is granted via
[googlegroups](https://groups.google.com/forum/#!forum/k8s-infra-gcp-auditors).

You must have a Google account that will let you access the Google Cloud
Console.

To volunteer for this effort, contact the main
[k8s-infra-team](https://groups.google.com/forum/#!forum/k8s-infra-team).

## Where is it hosted?

We mostly host it in Google Cloud:
  * GCP org = kubernetes.io / organizationId=758905017065
  * GCP project = kubernetes-public

## Requesting a Audit PR for review

The process for sumbitting an audit uses Github PRs.

### audit.sh

Run ./audit.sh to generate a current audit configuration dump.
Submit a PR to this repo with any new or updated files.

In the PR please review the following details:
   * The reason for any updates.
   * Discuss / link related PRs / issues.

Once this PR is created, it should be acknowledged by a secondary auditor.

### Performing an audit

#### Update Pull Request
First, the requsting auditor opens a PR with any updates applied to the appropriate YAML/JSON file.
Next, the requesting auditor validates that the PR looks correct for their request and responds `/lgtm`

The a secondary auditor merges the PR once it has been LGTM'd

## TODO

Administrative:
  * Who should be in OWNERS file
  * Audit report

How to automate:
  * How do we audit for iam changes as they happen, rather than polling
  * iam change triggers PR to github, notifies / tags the user who made the change
