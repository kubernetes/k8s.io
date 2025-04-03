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
resource "ibm_is_instance" "bastion" {
  count          = var.bastion.count
  name           = "bastion-s390x-${count.index + 1}"
  vpc            = data.ibm_is_vpc.vpc.id
  zone           = var.zone
  profile        = var.bastion.profile
  image          = var.image_id
  keys           = [ibm_is_ssh_key.k8s_ssh_key.id]
  resource_group = data.ibm_resource_group.resource_group.id
  primary_network_interface {
    name            = "public-nic"
    subnet          = data.ibm_is_subnet.subnet.id
    security_groups = [data.ibm_is_security_group.bastion_sg.id]
  }

  boot_volume {
    name = "boot-vol-bastion-${count.index}"
    size = var.bastion.boot_volume.size
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
                - [hostnamectl, set-hostname, "bastion-s390x-${count.index + 1}.s390x-vpc.cloud.ibm.com"]
                - [echo, "bastion-s390x-${count.index + 1}.s390x-vpc.cloud.ibm.com", ">", /etc/hostname]
                - [sed, -i, "s/^127.0.1.1.*/127.0.1.1\tbastion-s390x-${count.index + 1}.s390x-vpc.cloud.ibm.com/", /etc/hosts]
              EOF
}

resource "ibm_is_floating_ip" "bastion_fip" {
  count          = var.bastion.count
  name           = "bastion-fip-${count.index}"
  target         = ibm_is_instance.bastion[count.index].primary_network_interface[0].id
  resource_group = data.ibm_resource_group.resource_group.id
}

resource "time_sleep" "wait_for_bastion" {
  count      = var.bastion.count
  depends_on = [ibm_is_floating_ip.bastion_fip]

  create_duration = "180s" # Wait 3 minutes for full initialization
}

resource "null_resource" "bastion_setup" {
  count      = var.bastion.count
  depends_on = [time_sleep.wait_for_bastion]

  connection {
    type        = "ssh"
    user        = "root"
    host        = ibm_is_floating_ip.bastion_fip[count.index].address
    private_key = data.ibm_sm_arbitrary_secret.ssh_private_key.payload
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      # Network verification
      "echo '=== Network Interfaces ==='",
      "ip -4 addr show",
      "echo '=== Routing Table ==='",
      "ip route",
      "echo '=== NAT Configuration ==='",
      "iptables -t nat -L -n -v",
      "echo '=== IP Forwarding ==='",
      "sysctl net.ipv4.ip_forward",

      # Hostname verification
      "echo '=== Hostname ==='",
      "hostname",
      "hostnamectl",
      "cat /etc/hostname",

      # Final security updates
      "command -v apt-get >/dev/null && apt-get update -y && apt-get upgrade -y --security || true",
      "command -v yum >/dev/null && yum update -y --security || true",
      "command -v dnf >/dev/null && dnf update -y --security || true"
    ]
  }
}
