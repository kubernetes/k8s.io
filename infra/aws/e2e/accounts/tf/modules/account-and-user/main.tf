# Intermediate module; workaround for terraform being bad at multiple providers
module "account" {
  source = "../account"
  id     = var.id
  email  = var.email
}

module "user" {
  source = "../user"
  id     = var.id
  orgid  = module.account.orgid
}


# Create the boskos yaml file
# Workaround for terraform bugs around showing state/variables; we have to write from here
resource "local_file" "boskos" {
  filename          = "boskos/${var.boskos-name}.yaml"
  sensitive_content = <<EOF
apiVersion: boskos.k8s.io/v1
kind: ResourceObject
metadata:
  name: ${var.boskos-name}
  namespace: test-pods
  labels:
    terraform-id: ${var.id}
    terraform-email: ${var.email}
spec:
  type: aws-account
status:
  #owner: ""
  #state: free
  userData:
    access-key-id: "${module.user.aws_access_key_id}"
    secret-access-key: "${module.user.aws_secret_access_key}"

---

EOF
}
