#
# required
#
variable "project_name" {
    type = string
}

variable "project_id" {
    type = string
}

variable "env_name" {
    type = string
}


variable "group" { 
    type = string
}

variable "writer" {
    type = string
}

variable "enable_api" {
    type = string
}

variable "billing_account" {
	type = string
}

#
# optional
#

variable "custom_labels" {
    type = map
    default = {}
}
