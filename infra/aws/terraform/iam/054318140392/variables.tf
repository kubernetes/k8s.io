variable "region" {
  type = string
}

variable "eks_admins" {
  type        = list(string)
  description = "List of user names allowed to assume TerraformEKSProvisioner role."
  default     = []
}
