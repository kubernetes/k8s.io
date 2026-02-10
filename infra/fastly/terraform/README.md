We have several endpoints that we serve via Fastly.


Traffic Flow Diagram

Legacy Approach:

dl.k8s.io -> cdn.dl.k8s.io -> Fastly CDN -> GCS Bucket

Updated Approach

dl.k8s.dev -> Fastly CDN -> GCS Bucket

Services List:

|Address|Environment| Service ID |
|---|---|--|
| cdn.dl.k8s.io | Production | myOKWFV3A3TGNBOXkU5kk2 |
| dl.k8s.dev | Staging | UylsgjQtU5Y9hKw2Ue11j8 |
