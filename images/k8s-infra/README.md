# k8s-infra

Intended to hold all dependencies needed to build, test and run all tools used by wg-k8s-infra. With sufficient credentials mounted in, should be capable of running those tools to test and deploy all kubernetes project infrastructure managed by wg-k8s-infra.

One goal is to use this image for all of of our CI jobs, and make it easy to run locally to verify CI job changes prior to deployment.

## contents

- base:
  - debian as provided by `debian:buster`
- directories:
  - `/build` contains "info" or "version" output for each of the included tools/languages
  - `/workspace` default working directory for `run` commands
- languages:
  - `go`
  - `python3` and `pip3`
- tools:
  - `conftest`
  - `curl`
  - `gcc`
  - `gcloud` (via `apt-get` for smaller size); components include:
    - `bq`
    - `gcloud alpha`
    - `gcloud beta`
    - `gsutil`
  - `git`
  - `gh`
  - `jq`
  - `kubectl`
  - `make`
  - `opa`
  - `pr-creator` (from kubernetes/test-infra)
  - `shellcheck`
  - `terraform` (via `tfswitch`)
  - `tfswitch`
  - `yamlint`
  - `yq`

## usage

Example: build a local copy tagged as `gcr.io/this/is:fine` and use it to run `hack/verify-boilerplate.sh`:

```sh
export REPO=gcr.io/this IMAGE=is TAG=fine
make build
make run WHAT="hack/verify-boilerplate.sh"
```

Example: use Google Cloud Build in `my-project` with staging bucket `gs://my-bucket` to build/push `gcr.io/my-repo/k8s-infra:v{date}-{sha}`:

```sh
export PROJECT_ID=`my-project` GCB_BUCKET=`my-bucket` REPO=`gcr.io/my-repo`
make cloudbuild
```
