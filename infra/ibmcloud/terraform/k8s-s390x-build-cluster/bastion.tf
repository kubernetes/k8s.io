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
  bastion_nodes = {
    "primary" = {
      profile = var.bastion_profile
      boot_volume = {
        size = var.bastion_boot_volume_size
      }
    }
  }
}

resource "ibm_is_instance" "bastion" {
  for_each       = local.bastion_nodes
  name           = "bastion-s390x-${each.key}"
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = var.zone
  profile        = each.value.profile
  image          = data.ibm_is_image.os_image.id
  keys           = [ibm_is_ssh_key.k8s_ssh_key.id]
  resource_group = data.ibm_resource_group.resource_group.id

  primary_network_interface {
    name            = "public-nic-${each.key}"
    subnet          = data.ibm_is_subnet.subnet.id
    security_groups = [data.ibm_is_security_group.bastion.id]
  }

  boot_volume {
    name = "boot-vol-bastion-${each.key}"
    size = each.value.boot_volume.size
  }

  user_data = <<-EOF
              #cloud-config
              package_update: true
              package_upgrade: true
              packages:
                - tcpdump
                - net-tools
                - iptables-persistent
              write_files:
                - path: /etc/ssh/sshd_config.d/99-bastion.conf
                  content: |
                    AllowTcpForwarding yes
                    GatewayPorts yes
                    PermitTunnel yes
                    PermitRootLogin prohibit-password
                    PasswordAuthentication no
                    ClientAliveInterval 120
                    ClientAliveCountMax 3
                    MaxSessions 50
                    MaxStartups 50:30:100
                - path: /etc/systemd/network/10-eth1.network
                  content: |
                    [Match]
                    Name=eth1
                    [Network]
                    Address=${data.ibm_is_subnet.subnet.ipv4_cidr_block}
                    DNS=8.8.8.8
                    DNS=8.8.4.4
              runcmd:
                - [sysctl, -w, net.ipv4.ip_forward=1]
                - [echo, "net.ipv4.ip_forward = 1", ">>", /etc/sysctl.conf]
                - [iptables, -t, nat, -A, POSTROUTING, -o, eth0, -j, MASQUERADE]
                - [iptables, -A, FORWARD, -i, eth1, -o, eth0, -j, ACCEPT]
                - [iptables, -A, FORWARD, -i, eth0, -o, eth1, -m, state, --state, RELATED,ESTABLISHED, -j, ACCEPT]
                - [netfilter-persistent, save]
                - [systemctl, restart, systemd-networkd]
                - [systemctl, restart, sshd]
                - [hostnamectl, set-hostname, "bastion-s390x-${each.key}.s390x-vpc.cloud.ibm.com"]
                - [echo, "bastion-s390x-${each.key}.s390x-vpc.cloud.ibm.com", ">", /etc/hostname]
                - [sed, -i, "s/^127.0.1.1.*/127.0.1.1\tbastion-s390x-${each.key}.s390x-vpc.cloud.ibm.com/", /etc/hosts]
                - [touch, /var/lib/cloud/instance/bastion-setup-success]
              EOF
}

resource "ibm_is_floating_ip" "bastion_fip" {
  for_each       = ibm_is_instance.bastion
  name           = "bastion-fip-${each.key}"
  target         = each.value.primary_network_interface[0].id
  resource_group = data.ibm_resource_group.resource_group.id
}
