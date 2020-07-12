# AWS account scripting

* We create AWS accounts using terraform.

* The state file is stored (encrypted) in GCS.

* The encryption key is available only to those that should be running
  this, as it contains the AWS account keys.

* We additionally generate the boskos objects, and upload that also to
  GCS, encrypted using the same key (as it broadly has the same data)


## Applying to terraform

Ensure that the key is written to `gcs-encryption-key`

Ensure you are using the correct AWS profile, and then run tf-apply, for example:

```
export AWS_PROFILE=cncf
./tf-apply
```

## Uploading to boskos

Ensure that the encryption key is written to `gcs-encryption-key`

Ensure you are using the correct k8s context, then run `apply-to-k8s`.  For example:


```
gcloud container clusters get-credentials ...
./apply-to-k8s
```
