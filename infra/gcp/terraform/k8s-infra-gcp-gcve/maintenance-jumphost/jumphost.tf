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

locals {
  project_id = "broadcom-451918"
}

resource "google_compute_instance" "jumphost" {
  project      = local.project_id
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
    subnetwork_project = local.project_id
    access_config {
      network_tier = "STANDARD"
    }
  }

  # can_ip_forward = true

  metadata = {
    user-data = templatefile("${path.module}/cloud-config.yaml.tftpl", { wg0 = base64encode(data.google_secret_manager_secret_version_access.wireguard-config.secret_data) })
  }
}

data "google_secret_manager_secret_version_access" "wireguard-config" {
  project      = local.project_id
  secret = "maintenance-vm-wireguard-config"
}
