`gcsweb` is a tiny web frontend to [GCS](https://cloud.google.com/storage/docs/) browsing that DOES NOT REQUIRE A GOOGLE LOGIN.

See it in action: http://gcsweb.k8s.io/gcs/kubernetes-release/release/

#### Problem

`kubernetes` releases can be downloaded using direct API links to specific
files. However, to browse all available files at
https://console.cloud.google.com/storage/browser/kubernetes-release/release/
or with `gsutil` people
[need Google login](https://cloud.google.com/storage/docs/access-public-data).

#### Solution

Run a web app that uses pubic API to access public buckets, extract
information about directory structure and present it to the users with direct
links to specific files.

#### More info

1. `gcsweb` is just a tool, anyone can run it at any URL with any allowed
[buckets](https://cloud.google.com/storage/docs/key-terms#buckets) they want.

2. `gcsweb` is not designed for initial browsing (yet?) - it doesn't list
which GCS buckets are available, and because bucket is a part of URL, you
need a documented link to browse.

#### Installation and deployment

`gcsweb` is built from source code at
https://github.com/kubernetes/test-infra/tree/master/gcsweb into Docker
container, which is then uploaded to private container storage at
https://gcr.io/google_containers/gcsweb-amd64 and fetched during processing
of `deployment.yaml` by `kubectl apply`.
