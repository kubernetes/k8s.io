/*
Copyright 2025 The Kubernetes Authors.

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

variable "project_id" {
  description = "The project ID to use for the gcve cluster."
  default     = "broadcom-451918"
  type        = string
}

# Read the secret from Secret Manager which contains the wireguard server configuration. 
data "google_secret_manager_secret_version_access" "wireguard-config" {
  project      = var.project_id
  secret = "maintenance-vm-wireguard-config"
}

# Create the maintenance jumphost which runs SSH and a wireguard server.
resource "google_compute_instance" "jumphost" {
  project      = var.project_id
  name         = "maintenance-jumphost"
  machine_type = "f1-micro"
  zone         = "us-central1-f"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }

  network_interface {
    network = "maintenance-vpc-network"
    subnetwork = "maintenance-subnet"
    subnetwork_project = var.project_id
    access_config {
      network_tier = "STANDARD"
    }
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-config.yaml.tftpl", { wg0 = base64encode(data.google_secret_manager_secret_version_access.wireguard-config.secret_data) })
  }
}
