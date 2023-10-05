variable "prefix" {
  description = "Prefix for every resource so that the resources can be created without using the same names. Useful for testing and staging"
  type        = string
  default     = "test-"

  validation {
    condition     = can(regex(".*-$|^$", var.prefix))
    error_message = "The string must end with a hyphen or be empty."
  }
}
