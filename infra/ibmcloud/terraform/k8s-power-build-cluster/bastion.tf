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

data "ibm_pi_image" "image" {
  pi_image_name        = var.image_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_key" "key" {
  pi_key_name          = var.keypair_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_sm_arbitrary_secret" "secret" {
  instance_id       = var.secrets_manager_id
  region            = "us-south"
  name              = "build-cluster-ssh-private-key"
  secret_group_name = "default"
}

resource "ibm_pi_network" "private_network" {
  pi_network_name      = "private-net"
  pi_cloud_instance_id = var.service_instance_id
  pi_network_type      = "vlan"
  pi_dns               = ["9.9.9.9"]
  pi_cidr              = "192.168.25.0/24"
  pi_gateway           = "192.168.25.1"
  pi_ipaddress_range {
    pi_starting_ip_address = "192.168.25.2"
    pi_ending_ip_address   = "192.168.25.254"
  }
}

resource "ibm_pi_network" "public_network" {
  lifecycle {
    ignore_changes = [
      pi_advertise,
      pi_arp_broadcast,
    ]
  }
  pi_network_name      = "public-net"
  pi_cloud_instance_id = var.service_instance_id
  pi_network_type      = "pub-vlan"
  pi_dns               = ["9.9.9.9"]
}

resource "ibm_pi_instance" "bastion" {

  pi_memory            = var.bastion["memory"]
  pi_processors        = var.bastion["processors"]
  pi_instance_name     = "bastion"
  pi_proc_type         = var.processor_type
  pi_image_id          = data.ibm_pi_image.image.id
  pi_key_pair_name     = var.keypair_name
  pi_sys_type          = var.system_type
  pi_storage_type      = var.storage_type
  pi_cloud_instance_id = var.service_instance_id
  pi_health_status     = var.bastion_health_status

  pi_network {
    network_id = ibm_pi_network.public_network.network_id
  }
  pi_network {
    network_id = ibm_pi_network.private_network.network_id
    ip_address = "192.168.25.2"
  }
}

resource "null_resource" "bastion_setup" {
  depends_on = [ibm_pi_instance.bastion]

  connection {
    type        = "ssh"
    user        = "root"
    host        = data.ibm_pi_instance_ip.bastion_public_ip.external_ip
    private_key = data.ibm_sm_arbitrary_secret.secret.payload
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }
  provisioner "remote-exec" {
    inline = [<<EOF
sudo sed -i.bak -e 's/^ - set_hostname/# - set_hostname/' -e 's/^ - update_hostname/# - update_hostname/' /etc/cloud/cloud.cfg
sudo hostnamectl set-hostname --static bastion.power-iaas.cloud.ibm.com
echo 'HOSTNAME=bastion.power-iaas.cloud.ibm.com' | sudo tee -a /etc/sysconfig/network > /dev/null
sudo hostname -F /etc/hostname
EOF
    ]
  }
  provisioner "remote-exec" {
    inline = [<<EOF
dnf update -y
systemctl reboot
EOF
    ]
  }
}

data "ibm_pi_instance_ip" "bastion_ip" {
  depends_on = [ibm_pi_instance.bastion]

  pi_instance_name     = ibm_pi_instance.bastion.pi_instance_name
  pi_network_name      = ibm_pi_network.private_network.pi_network_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_instance_ip" "bastion_public_ip" {
  depends_on = [ibm_pi_instance.bastion]

  pi_instance_name     = ibm_pi_instance.bastion.pi_instance_name
  pi_network_name      = ibm_pi_network.public_network.pi_network_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_network" "private_network" {
  depends_on = [ibm_pi_network.private_network]

  pi_network_name      = "private-net"
  pi_cloud_instance_id = var.service_instance_id
}
