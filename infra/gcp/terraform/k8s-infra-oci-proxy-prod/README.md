## AWS ↔ GCP region pairing and mapping

This document contains the GCP regions that we serve image registries from including future regions.

At a high level:
  - A global GCP loadbalancer routes traffic to the closest Cloud Run service
  - Image Manifests are fetched from GCP
  - Traffic originating from GCP fetches image blobs from GCP Artifact Registry
  - Traffic originating from AWS fetches image blobs from S3 Buckets
  - Traffic originating from outside of GCP and AWS is fetched from S3 buckets
  - If a GCP region doesn't have an paired AWS region, the user fetches image blobs from AWS Cloudfront CDN.

| Metro / Country | AWS region | GCP region | Is the GCP region deployed? | Blobs served from GCP to non cloud users? | Active GCP Image Registry | Active S3 Bucket | Nearest Blob Location 
|---|---|---|---|---|---|---|---|
| South Africa | `af-south-1` | `africa-south1` | 🔴 | No | No | Yes | Same Region | Same Region |
| Taiwan | `ap-east-2` | `asia-east1` | 🟢 | No | Yes | Yes | Same Region |
| Hong Kong (SAR) | `ap-east-1` | `asia-east2` | 🔴 | No | No | Yes | Same Region | Same Region |
| Tokyo, Japan | `ap-northeast-1` | `asia-northeast1` | 🟢 | No | Yes | Yes | Same Region |
| Osaka, Japan | `ap-northeast-3` | `asia-northeast2` | 🟢 | No | Yes | Yes | Same Region |
| Seoul, South Korea | `ap-northeast-2` | `asia-northeast3` | 🔴 | No | No | Yes | Same Region |
| Mumbai, India | `ap-south-1` | `asia-south1` | 🟢 | No | Yes | Yes | Same Region |
| Hydrebad, India | — | `asia-south2` | 🔴 | No | No | — | AWS Cloudfront |
| Singapore | `ap-southeast-1` | `asia-southeast1` | 🔴 | No | Yes | Yes | Same Region |
| Jakarta, Indonesia | `ap-southeast-3` | `asia-southeast2` | 🔴 | No | Yes | Yes | Same Region |
| Sydney, Australia | `ap-southeast-2` | `australia-southeast1`| 🟢 | No | Yes | Yes | Same Region |
| Melbourne, Australia | `ap-southeast-4` | `australia-southeast2` | 🔴 | No | No | Yes | Same Region |
| Warsaw, Poland | — | `europe-central2` |  🔴 | No | No | — | AWS Cloudfront |
| Hamina, Finland | — | `europe-north1` |  🟢 | No | Yes | — | AWS Cloudfront |
| Stockholm, Sweden | `eu-north-1` | `europe-north2` | 🔴  | No | No | Yes | Same Region |
| Madrid, Spain | `eu-south-2` | `europe-southwest1` | 🟢 | No | Yes | Yes | Same Region |
| St. Ghislain, Belgium | — | `europe-west1` | 🟢 | No | Yes | — | Europe |
| London, UK | `eu-west-2` | `europe-west2` | 🟢 | No | Yes | Yes | Same Region |
| Frankfurt, Germany | `eu-central-1` | `europe-west3` | 🟢 | No | Yes | Yes | Same Region |
| Eemshaven, Netherlands | — | `europe-west4` | 🟢 | No | Yes | Yes | Europe |
| Zürich, Switzerland | `eu-central-2` | `europe-west6` | 🔴 | No | No | Yes | Same Region |
| Milan, Italy | `eu-south-1` | `europe-west8` | 🟢 | No | Yes | Yes | Same Region |
| Paris, France | `eu-south-2` | `europe-west9` | 🟢 | No | Yes | Yes | Same Region |
| Berlin, Germany | — | `europe-west10` | 🟢 | No | Yes | Yes | Same Country |
| Turin, Italy | — | `europe-west12` | 🔴 | No | No | — | AWS Cloudfront |
| Doha, Qatar | — | `me-central1` | 🔴 | No | No | — | AWS Cloudfront |
| Dammam, Saudi Arabia | — | `me-central2` | 🔴 | No | No | — | AWS Cloudfront |
| Tel Aviv, Israel | `il-central-1` | `me-west1` | 🔴 | No | No | Yes | Europe |
| Montréal, Canada | `ca-central-1` | `northamerica-northeast1` | 🔴 | No | No | Yes | Same Region |
| Toronto, Canada | — | `northamerica-northeast2` | 🔴 | No | No | — | AWS Cloudfront |
| Querétaro, Mexico | `mx-central-1` | `northamerica-south1` | 🔴 | No | No | Yes | Same Region |
| São Paulo, Brazil | `sa-east-1` | `southamerica-east1` | 🔴 | No | No | Yes | Same Region |
| Santiago, Chile | — | `southamerica-west1` | 🟢 | No | Yes | No | AWS Cloudfront |
| Council Bluffs (Iowa), USA | — | `us-central1` | 🟢 | No | Yes | Yes | `us-east-2` |
| Moncks Corner (South Carolina), USA | — | `us-east1` | 🟢 | No | Yes | — | `us-east-1` |
| Ashburn (N. Virginia), USA | `us-east-1` | `us-east4` | 🟢 | No | Yes | Yes | Same Region |
| Columbus (Ohio), USA | `us-east-2` | `us-east5` | 🟢 | No | Yes | Yes | Same Region |
| Dallas (Texas), USA | — | `us-south1` | 🟢 | No | Yes | — | `us-east-2` |
| The Dalles (Oregon), USA | `us-west-2` | `us-west1` | 🟢 | No | Yes | Yes | Same Region |
| California, USA | `us-west-1` | `us-west2` | 🟢 | No | Yes | Yes | Same Region |
| Salt Lake City (Utah), USA | — | `us-west3` | 🔴 | No | No | — | AWS Cloudfront |
| Las Vegas (Nevada), USA | — | `us-west4` | 🔴 | No | No | — | AWS Cloudfront  |


Priority Regions:
- P1
    - `af-south-1`. 1st region in Africa
    - `me-central1`. 1st region in the Middle East
    - `asia-east2`. A paired region that will also serve AWS China traffic.
    - `northamerica-northeast1`. First paired region in Canada
- P2 
   - `europe-north2`. A paired region
   - `northamerica-south1` A paired region
   - `asia-southeast1`. A paired region
- Backlog
   - Remaining US regions

Regions we should replace given promoter capacity:
  - `asia-northeast2`, another region of the same country is already active
  - `europe-west10`, another region of the same country is already active

As of 13th of December 2025, all the AWS regions that publicly available have been populated and configured in archeio.

```
# aws ec2 describe-regions --all-regions --query "Regions[].RegionName" --output json | jq .[] | awk '{print $0","}' | sort --version-sort
"af-south-1",
"ap-east-1",
"ap-east-2",
"ap-northeast-1",
"ap-northeast-2",
"ap-northeast-3",
"ap-southeast-1",
"ap-southeast-2",
"ap-southeast-3",
"ap-southeast-4",
"ap-southeast-5",
"ap-southeast-6",
"ap-southeast-7",
"ap-south-1",
"ap-south-2",
"ca-central-1",
"ca-west-1",
"eu-central-1",
"eu-central-2",
"eu-north-1",
"eu-south-1",
"eu-south-2",
"eu-west-1",
"eu-west-2",
"eu-west-3",
"il-central-1",
"me-central-1",
"me-south-1",
"mx-central-1",
"sa-east-1",
"us-east-1",
"us-east-2",
"us-west-1",
"us-west-2",
```

Helpful Guides:
- https://cloudregionsmap.z6.web.core.windows.net/
