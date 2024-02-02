# Kubecost Installation

Some manual actions need to be taken before Flux takes over the process.

## AWS Preperations

Kubecost requires some configuration on AWS side:

<details>
  <summary>policy-kubecost-aws-s3.json</summary>

  ```json
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "VisualEditor0",
              "Effect": "Allow",
              "Action": [
                  "s3:ListBucket",
                  "s3:GetBucketLocation"
              ],
              "Resource": "arn:aws:s3:::kubecost-prow-clusters-metrics"
          },
          {
              "Sid": "VisualEditor1",
              "Effect": "Allow",
              "Action": [
                  "s3:PutObject",
                  "s3:GetObject",
                  "s3:ListBucketMultipartUploads",
                  "s3:AbortMultipartUpload",
                  "s3:ListBucket",
                  "s3:DeleteObject",
                  "s3:ListMultipartUploadParts"
              ],
              "Resource": [
                  "arn:aws:s3:::kubecost-prow-clusters-metrics",
                  "arn:aws:s3:::kubecost-prow-clusters-metrics/*"
              ]
          }
      ]
  }
  ```
</details>

Create the IAM policy and the namespace:

```bash
aws iam create-policy \
 --policy-name kubecost-s3-federated-policy \
 --policy-document file://policy-kubecost-aws-s3.json

kubectl create namespace kubecost
```

Create a secret to access to the S3 bucket for the federation. 

> [!IMPORTANT]
> The `federated-store.yaml` must be updated with the correct AWS credentials

<details>
  <summary>federated-store.yaml</summary>

  ```yaml
  type: S3
  config:
    bucket: "kubecost-prow-clusters-metrics"
    endpoint: "s3.amazonaws.com"
    region: "us-east-2"
    access_key: "xxx"
    secret_key: "yyy"
    insecure: false
    signature_version2: false
    put_user_metadata:
        "X-Amz-Acl": "bucket-owner-full-control"
    http_config:
      idle_conn_timeout: 90s
      response_header_timeout: 2m
      insecure_skip_verify: false
    trace:
      enable: true
    part_size: 134217728
  ```
</details>

```bash
kubectl create secret generic \
  kubecost-object-store -n kubecost \
  --from-file federated-store.yaml
```

Create the service account in the EKS cluster

```bash
eksctl utils associate-iam-oidc-provider \
    --cluster prow-build-cluster \
    --region us-east-2 \
    --approve

eksctl create iamserviceaccount \
    --name kubecost-irsa-s3 \
    --namespace kubecost \
    --cluster prow-build-cluster \
    --region us-east-2 \
    --attach-policy-arn arn:aws:iam::468814281478:policy/kubecost-s3-federated-policy \
    --approve
```

## Kubecost Enterprise Key

A Secret must be created containing the product key:

```bash
# productkey.json content is in this format:
# { "key": "KC-XXXX-YYYY-ZZZZ" }

kubectl create secret generic kubecost-product-key \
  --from-file=productkey.json -n kubecost
```
