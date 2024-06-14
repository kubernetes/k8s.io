module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name
  create_access_entry = false

  enable_irsa = true
  irsa_namespace_service_accounts = ["karpenter:karpenter"]
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    Environment = var.cluster_name == "prow-canary-cluster" ? "canary" : "prod"
    Terraform   = "true"
  }
}
