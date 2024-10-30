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

resource "ibm_pi_instance" "control_plane" {

  count                = var.control_plane["count"]
  pi_memory            = var.control_plane["memory"]
  pi_processors        = var.control_plane["processors"]
  pi_instance_name     = "control-plane-${count.index}"
  pi_proc_type         = var.processor_type
  pi_image_id          = data.ibm_pi_image.image.id
  pi_key_pair_name     = var.keypair_name
  pi_sys_type          = var.system_type
  pi_storage_type      = var.storage_type
  pi_cloud_instance_id = var.service_instance_id
  pi_health_status     = "WARNING"

  pi_network {
    network_id = ibm_pi_network.private_network.network_id
  }
}

resource "null_resource" "control_plane_setup" {
  depends_on = [ibm_pi_instance.control_plane]
  count      = var.control_plane["count"]

  connection {
    type         = "ssh"
    user         = "root"
    host         = data.ibm_pi_instance_ip.control_plane_ip[count.index].ip
    private_key  = data.ibm_sm_arbitrary_secret.secret.payload
    agent        = var.ssh_agent
    timeout      = "${var.connection_timeout}m"
    bastion_host = data.ibm_pi_instance_ip.bastion_public_ip.external_ip
  }
  provisioner "remote-exec" {
    inline = [<<EOF
sudo sed -i.bak -e 's/^ - set_hostname/# - set_hostname/' -e 's/^ - update_hostname/# - update_hostname/' /etc/cloud/cloud.cfg
sudo hostnamectl set-hostname --static control-plane-${count.index}.power-iaas.cloud.ibm.com
echo 'HOSTNAME=control-plane-${count.index}.power-iaas.cloud.ibm.com' | sudo tee -a /etc/sysconfig/network > /dev/null
sudo hostname -F /etc/hostname
EOF
    ]
  }
}

resource "ibm_pi_instance" "compute" {

  count                = var.compute["count"]
  pi_memory            = var.compute["memory"]
  pi_processors        = var.compute["processors"]
  pi_instance_name     = "compute-${count.index}"
  pi_proc_type         = var.processor_type
  pi_image_id          = data.ibm_pi_image.image.id
  pi_key_pair_name     = var.keypair_name
  pi_sys_type          = var.system_type
  pi_storage_type      = var.storage_type
  pi_cloud_instance_id = var.service_instance_id
  pi_health_status     = "WARNING"

  pi_network {
    network_id = ibm_pi_network.private_network.network_id
  }
}

resource "null_resource" "compute_setup" {
  depends_on = [ibm_pi_instance.compute]
  count      = var.compute["count"]

  connection {
    type         = "ssh"
    user         = "root"
    host         = data.ibm_pi_instance_ip.compute_ip[count.index].ip
    private_key  = data.ibm_sm_arbitrary_secret.secret.payload
    agent        = var.ssh_agent
    timeout      = "${var.connection_timeout}m"
    bastion_host = data.ibm_pi_instance_ip.bastion_public_ip.external_ip
  }
  provisioner "remote-exec" {
    inline = [<<EOF
sudo sed -i.bak -e 's/^ - set_hostname/# - set_hostname/' -e 's/^ - update_hostname/# - update_hostname/' /etc/cloud/cloud.cfg
sudo hostnamectl set-hostname --static compute-${count.index}.power-iaas.cloud.ibm.com
echo 'HOSTNAME=compute-${count.index}.power-iaas.cloud.ibm.com' | sudo tee -a /etc/sysconfig/network > /dev/null
sudo hostname -F /etc/hostname
EOF
    ]
  }
}

data "ibm_pi_instance_ip" "control_plane_ip" {
  depends_on = [ibm_pi_instance.control_plane]
  count      = var.control_plane["count"]

  pi_instance_name     = ibm_pi_instance.control_plane[count.index].pi_instance_name
  pi_network_name      = var.network_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_instance_ip" "compute_ip" {
  depends_on = [ibm_pi_instance.compute]
  count      = var.compute["count"]

  pi_instance_name     = ibm_pi_instance.compute[count.index].pi_instance_name
  pi_network_name      = var.network_name
  pi_cloud_instance_id = var.service_instance_id
}
