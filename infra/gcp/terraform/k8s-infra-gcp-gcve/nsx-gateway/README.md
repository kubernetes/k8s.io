# NSX Gateway

TODO: describe what this does
TODO: link from top-level readme's

The wireguard config will look like

```ini
[Interface]
PrivateKey = ...
Address = 192.168.29.6/24
PostUp = iptables -t nat -I POSTROUTING -o wg0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o wg0 -j MASQUERADE

[Peer]
Endpoint = 192.168.28.3:51820
PublicKey = ...
PersistentKeepalive = 25
# all except private networks
AllowedIPs = 0.0.0.0/5, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/2, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/6, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/10, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4, 224.0.0.0/3
```

To get SSH access to the VM, redeploy using:

```sh
 export TF_VAR_ssh_public_key="ssh-rsa ..."
terraform taint vsphere_virtual_machine.gateway_vm
terraform apply
```

Note: Redeployment causes connection issues for running CI jobs.
