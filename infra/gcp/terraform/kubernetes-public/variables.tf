/*
Copyright 2021 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#  This contains default variables used by Terraform resources

variable "node_image_type" {
  type        = string
  default     = "COS_CONTAINERD"
  description = "Image type for GKE pool node"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The default region for resources in the project"
}

variable "db_location" {
  type        = string
  default     = "us-central1"
  description = "# The region in which to put the SQL DB: it is currently configured to use"
}

# database name, not instance name
variable "db_name" {
  type    = string
  default = "k8s-infra-elections-db"
}

variable "db_user" {
  type    = string
  default = "user"
}

variable "db_version" {
  type        = string
  default     = "POSTGRES_13"
  description = "Version of the database to use. Must be at least 13 or higher."
}

variable "database_backup_location" {
  type        = string
  default     = "us"
  description = "Location in which to backup the database."
}

variable "database_backup_schedule" {
  type        = string
  default     = "0 */10 * * *"
  description = "Cron schedule in which to do a full backup of the database to Cloud Storage."
}

variable "disk_autoresize" {
  type        = bool
  default     = true
  description = "Configuration to increase storage size."
}

variable "disk_autoresize_limit" {
  type        = number
  default     = 20
  description = "Disk size limit of the database"
}

variable "disk_type" {
  type        = string
  default     = "PD_SSD"
  description = "The disk type for the master instance."
}

variable "network_location" {
  type        = string
  default     = "us-central1"
  description = "The region for the networking components."
}

variable "storage_location" {
  type        = string
  default     = "US"
  description = "The location holding the storage bucket for exported files."
}

variable "cloudsql_tier" {
  type        = string
  default     = "db-custom-1-3840"
  description = "Custom configuration for the Cloud SQL instance. Matches 1 CPU and 3840MB"
}

variable "cloudsql_disk_size_gb" {
  type    = number
  default = 10

  description = "Size of the Cloud SQL disk, in GB."
}

variable "cloudsql_max_connections" {
  type    = number
  default = 200

  description = "Maximum number of allowed connections. If you change to a smaller instance size, you must lower this number."
}

variable "cloudsql_backup_location" {
  type    = string
  default = "us"

  description = "Location in which to backup the database."
}

variable "log_retention_period" {
  type        = number
  default     = 14
  description = "Number of days to retain logs for all services in the project"
}
