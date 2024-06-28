variable "location" {
  type        = string
  default     = "eastus"
  description = "Location of the resource group."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
  default     = "capz-ci"
}