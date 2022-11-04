# cs-fetch-repos

Utility python script that runs as an `initContainer` for the **codesearch** application (aka Hound). 

This script generates the `/data/config.json` file that configures the git repos for codesearch to index. 

## Setup

You can override the output destination of your `config.json` by specifying the `CONFIG_PATH` env variable. 

```sh
$ export CONFIG_PATH="/tmp/config.json"
$ python src/fetch-repos.py
Starting Fetch Repo Script..
File config saved to: /tmp/config.json
```

To add a new repo, update `REPOS` in the `fetch-repos.py` script.
```
REPOS = [
    'kubernetes',
    'kubernetes-client',
    'kubernetes-csi',
    'kubernetes-incubator',
    'kubernetes-sigs',
]
```

## Usage

Example: build a local copy tagged as `gcr.io/this/is:fine`:

```sh
export REPO=gcr.io/this IMAGE=is TAG=fine
make build
make run
```

Example: use Google Cloud Build in `my-project` with staging bucket `gs://my-bucket` to build/push `gcr.io/my-repo/k8s-infra:v{date}-{sha}`:

```sh
export PROJECT_ID=`my-project` GCB_BUCKET=`my-bucket` REPO=`gcr.io/my-repo`
make cloudbuild
```
