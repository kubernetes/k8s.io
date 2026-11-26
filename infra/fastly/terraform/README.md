We have several endpoints that we serve via Fastly.

- dl.k8s.io - Servers our kubernetes release assets from our prod release bucket
- artifacts.k8s.io - Servers non kubernetes assets from GCS
- dl.k8s.dev - Servers our release assets from our staging release bucket
- pkgs.k8s.io - Serves deb/rpm packages published by OpenBuildService (OBS) from S3
- pkgs.k8s.dev - Serves the same packages as pkgs.k8s.io, used for testing

dl.k8s.dev main purpose is to test CDN changes and then apply it to dl.k8s.io


Traffic Flow Diagram

dl.k8s.io -> Fastly CDN -> GCS Bucket

pkgs.k8s.io -> Fastly CDN -> S3 Bucket (prod-cdn-packages-k8s-io-eu-central-1)

Services List:

|Address|Environment| Service ID |
|---|---|---|
| dl.k8s.io | Production | myOKWFV3A3TGNBOXkU5kk2 |
| artifacts.k8s.io | Production |
| dl.k8s.dev | Staging | UylsgjQtU5Y9hKw2Ue11j8 |
| artifacts.k8s.dev | Staging | jgz1yYCC4yqh1ZoGhU8Nih |
| pkgs.k8s.io | Production |
| pkgs.k8s.dev | Staging |

## pkgs.k8s.io

pkgs.k8s.io and pkgs.k8s.dev serve the `prod-cdn-packages-k8s-io-eu-central-1`
S3 bucket (managed in `infra/aws/terraform/cdn.packages.k8s.io`) where OBS
publishes packages. Requests are rewritten to the OBS project path, e.g.
`/core:/stable:/v1.34/deb/` is fetched from
`/repositories/isv:/kubernetes:/core:/stable:/v1.34/deb/`, and `/` redirects
to the pkgs.k8s.io introduction blog post.

The bucket is private, so Fastly signs (SigV4) origin requests using the
`fastly-reader` IAM user from the `k8s-infra-obs-k8s-io-prod` AWS account
(managed in `infra/aws/cloudformation/iam/cdn.packages.k8s.io`). Its access
key must be stored in the following GCP Secret Manager secrets in the
`k8s-infra-releases-prod` project:

- `fastly_pkgs_reader_access_key`
- `fastly_pkgs_reader_secret_key`
