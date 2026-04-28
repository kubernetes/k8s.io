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
data "ibm_resource_group" "resource_group" {
  name = "rg-build-cluster"
}

data "ibm_is_vpc" "vpc" {
  name = "k8s-s390x-vpc"
}

data "ibm_is_subnet" "subnet" {
  name = "k8s-s390x-subnet"
}

data "ibm_is_security_group" "bastion" {
  name = "k8s-vpc-s390x-bastion-sg"
  vpc  = data.ibm_is_vpc.vpc.id
}

data "ibm_is_security_group" "control_plane_sg" {
  name = "k8s-vpc-s390x-control-plane-sg"
  vpc  = data.ibm_is_vpc.vpc.id
}

data "ibm_is_security_group" "worker_sg" {
  name = "k8s-vpc-s390x-worker-sg"
  vpc  = data.ibm_is_vpc.vpc.id
}

data "ibm_sm_arbitrary_secret" "ssh_private_key" {
  instance_id       = var.secrets_manager_id
  region            = var.region
  name              = "zvsi-ssh-private-key"
  secret_group_name = "default"
}

data "ibm_sm_arbitrary_secret" "ssh_public_key" {
  instance_id       = var.secrets_manager_id
  region            = var.region
  name              = "zvsi-ssh-public-key"
  secret_group_name = "default"
}
data "ibm_is_image" "os_image" {
  name = var.image_name
}
