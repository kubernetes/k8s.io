# Maintenance VM

## Reprovisioning

```sh
terraform taint google_compute_instance.jumphost
terraform apply
```

## Configuration

### Configure a connection

First we need to generate a wireguard keypair using `wg` (install on ubuntu via `apt-get install wireguard-tools`)

```sh
export CLIENT_PRIVATE_KEY="$(wg genkey)"
export CLIENT_PUBLIC_KEY="$(echo $CLIENT_PRIVATE_KEY | wg pubkey)"
```

Next we have to pick a free IP address from the `192.168.29.0/24` subnet, which is not already in the server config file (see gcloud secret `maintenance-vm-wireguard-config`):

```sh
export CLIENT_IP_ADDRESS="192.168.29.X"
```

After that we generate a peer entry for the server configuration by using the output of the following script:

```sh
cat << EOF
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP_ADDRESS}/32

EOF
```

Then we add it to the secret `maintenance-vm-wireguard-config` [here](https://console.cloud.google.com/security/secret-manager/secret/maintenance-vm-wireguard-config/versions).

To add it to a running VM:

```sh
gcloud compute ssh maintenance-jumphost
sudo systemctl stop wg-quick@wg0
sudo vim /etc/wireguard/wg0.conf
sudo systemctl start wg-quick@wg0
```

Last we generate a wireguard client configuration:

```sh
cat << EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP_ADDRESS}/24
MTU = 1360

[Peer]
PublicKey = $(gcloud secrets versions access --secret maintenance-vm-wireguard-pubkey latest)
AllowedIPs = 192.168.30.0/24, 192.168.32.0/21
Endpoint = $(gcloud compute instances list --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --filter='name=maintenance-jumphost'):51820
PersistentKeepalive = 25
EOF
```
