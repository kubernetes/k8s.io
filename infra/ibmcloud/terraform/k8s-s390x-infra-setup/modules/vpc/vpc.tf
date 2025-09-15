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
resource "ibm_is_vpc" "vpc" {
  name           = "k8s-s390x-vpc"
  resource_group = var.resource_group_id
}

# VPC
resource "ibm_is_public_gateway" "public_gw" {
  name           = "k8s-s390x-public-gw"
  vpc            = ibm_is_vpc.vpc.id
  zone           = var.zone
  resource_group = var.resource_group_id
}

# Subnet
resource "ibm_is_subnet" "subnet" {
  name                     = "k8s-s390x-subnet"
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = var.zone
  resource_group           = var.resource_group_id
  total_ipv4_address_count = 256
  public_gateway           = ibm_is_public_gateway.public_gw.id
}

# Security Groups
resource "ibm_is_security_group" "bastion_sg" {
  name           = "k8s-vpc-s390x-bastion-sg"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = var.resource_group_id
}

resource "ibm_is_security_group" "control_plane_sg" {
  name           = "k8s-vpc-s390x-control-plane-sg"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = var.resource_group_id
}

resource "ibm_is_security_group" "worker_sg" {
  name           = "k8s-vpc-s390x-worker-sg"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = var.resource_group_id
}

# Security Group Rules
resource "ibm_is_security_group_rule" "bastion_inbound_ssh" {
  group     = ibm_is_security_group.bastion_sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "bastion_outbound_all" {
  group     = ibm_is_security_group.bastion_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

## Master Rules

resource "ibm_is_security_group_rule" "worker_inbound_ssh_from_bastion" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "inbound"
  remote    = ibm_is_security_group.bastion_sg.id
  tcp {
    port_min = 22
    port_max = 22
  }
}


resource "ibm_is_security_group_rule" "worker_internal" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "inbound"
  remote    = ibm_is_subnet.subnet.ipv4_cidr_block
}

resource "ibm_is_security_group_rule" "worker_control_plane_all" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "inbound"
  remote    = ibm_is_security_group.control_plane_sg.id
}

resource "ibm_is_security_group_rule" "bastion_private_inbound" {
  group     = ibm_is_security_group.bastion_sg.id
  direction = "inbound"
  remote    = ibm_is_subnet.subnet.ipv4_cidr_block
}

resource "ibm_is_security_group_rule" "bastion_private_outbound" {
  group     = ibm_is_security_group.bastion_sg.id
  direction = "outbound"
  remote    = ibm_is_subnet.subnet.ipv4_cidr_block
}


resource "ibm_is_security_group_rule" "control_plane_to_worker_kubelet_api" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "inbound"
  remote    = ibm_is_security_group.control_plane_sg.id
  tcp {
    port_min = 10250
    port_max = 10250
  }
}
resource "ibm_is_security_group_rule" "allow_control_plane_to_worker_all" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "inbound"
  remote    = ibm_is_security_group.control_plane_sg.id
  tcp {
    port_min = 1
    port_max = 65535
  }
}

resource "ibm_is_security_group_rule" "allow_bastion_ssh_to_worker" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "inbound"
  remote    = ibm_is_security_group.bastion_sg.id
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "allow_vpc_cidr_to_worker" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "inbound"
  remote    = ibm_is_subnet.subnet.ipv4_cidr_block
  tcp {
    port_min = 1
    port_max = 65535
  }
}
resource "ibm_is_security_group_rule" "outbound_http" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "outbound_https" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_security_group_rule" "outbound_dns_tcp" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "outbound_dns_udp" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  udp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "outbound_k8s_api" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 6443
    port_max = 6443
  }
}

resource "ibm_is_security_group_rule" "worker_outbound_to_all" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "worker_pod_inbound" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "inbound"
  remote    = ibm_is_subnet.subnet.ipv4_cidr_block
  tcp {
    port_min = 10250
    port_max = 10250
  }
}

resource "ibm_is_security_group_rule" "worker_pod_outbound" {
  group     = ibm_is_security_group.worker_sg.id
  direction = "outbound"
  remote    = ibm_is_subnet.subnet.ipv4_cidr_block
  tcp {
    port_min = 10250
    port_max = 10250
  }
}

resource "ibm_is_security_group_rule" "control_plane_inbound_from_workers" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "inbound"
  remote    = ibm_is_security_group.worker_sg.id
}

resource "ibm_is_security_group_rule" "control_plane_inbound_from_bastion_ssh" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "inbound"
  remote    = ibm_is_security_group.bastion_sg.id
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "control_plane_inbound_from_internal_cidr" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "inbound"
  remote    = ibm_is_subnet.subnet.ipv4_cidr_block
}

resource "ibm_is_security_group_rule" "control_plane_inbound_from_self" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "inbound"
  remote    = ibm_is_security_group.control_plane_sg.id
}

resource "ibm_is_security_group_rule" "control_plane_inbound_api" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 6443
    port_max = 6443
  }
}
resource "ibm_is_security_group_rule" "control_plane_outbound_http" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "outbound"
  tcp {
    port_min = 80
    port_max = 80
  }
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "control_plane_outbound_https" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "outbound"
  tcp {
    port_min = 443
    port_max = 443
  }
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "control_plane_outbound_dns_tcp" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "outbound"
  tcp {
    port_min = 53
    port_max = 53
  }
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "control_plane_outbound_dns_udp" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "outbound"
  udp {
    port_min = 53
    port_max = 53
  }
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "control_plane_outbound_api" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "outbound"
  tcp {
    port_min = 6443
    port_max = 6443
  }
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "control_plane_outbound_to_workers" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "outbound"
  remote    = ibm_is_security_group.control_plane_sg.id
}

resource "ibm_is_security_group_rule" "control_plane_outbound_to_all" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}
resource "ibm_is_security_group_rule" "control_plane_pod_inbound" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "inbound"
  remote    = ibm_is_subnet.subnet.ipv4_cidr_block
  tcp {
    port_min = 10250
    port_max = 10250
  }
}

resource "ibm_is_security_group_rule" "control_plane_pod_outbound" {
  group     = ibm_is_security_group.control_plane_sg.id
  direction = "outbound"
  remote    = ibm_is_subnet.subnet.ipv4_cidr_block
  tcp {
    port_min = 10250
    port_max = 10250
  }
}
