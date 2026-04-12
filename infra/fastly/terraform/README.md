We have several endpoints that we serve via Fastly.

- dl.k8s.io - Servers our kubernetes release assets from our prod release bucket
- artifacts.k8s.io - Servers non kubernetes assets from GCS
- dl.k8s.dev - Servers our release assets from our staging release bucket

dl.k8s.dev main purpose is to test CDN changes and then apply it to dl.k8s.io


Traffic Flow Diagram

dl.k8s.io -> Fastly CDN -> GCS Bucket

Services List:

|Address|Environment| Service ID |
|---|---|---|
| dl.k8s.io | Production | myOKWFV3A3TGNBOXkU5kk2 |
| artifacts.k8s.io | Production |
| dl.k8s.dev | Staging | UylsgjQtU5Y9hKw2Ue11j8 |
| artifacts.k8s.dev | Staging | jgz1yYCC4yqh1ZoGhU8Nih |
