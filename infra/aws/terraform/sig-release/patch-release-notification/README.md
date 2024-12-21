# patch-release-notification service

This terraform code deploys the code to notify the K8s community about the cherry pick deadline for the patch releases.

The patch-release-notification code can be found in `cmd/patch-release-notification`

Right now, the terraform is applied manually by the release managers that have access to the AWS account for the SIG-release.

# Deploy

To deploy will require to have both repositories cloned:

- https://github.com/kubernetes/release/
- https://github.com/kubernetes/k8s.io

from https://github.com/kubernetes/k8s.io

```
# loging to the AWS ECR
$ aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 433650573627.dkr.ecr.us-west-2.amazonaws.com

$ cd k8s.io/infra/aws/terraform/sig-release/patch-release-notification

$ terraform init

$ terraform plan -out=plan.out

$ terraform apply "plan.out"
```

_note_: you will need to configure your AWS credentials before.
_note2_: this is setup to run in the AWS SIG-Release account.
