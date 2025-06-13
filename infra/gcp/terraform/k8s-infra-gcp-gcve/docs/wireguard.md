# Wireguard

Wireguard is used to get a secure and convenient access through the maintenace jump host VM.

In order to use wireguard you must be enabled to use the "broadcom-451918" project, please reach out to [owners](../OWNERS) in case of need.

It is also required to first setup things both on your local machine and on the GCP side
following the instruction below.

Install wireguard following one of the methods described in https://www.wireguard.com/install/.

Note: On OSX to use the commandline tool, installation via `brew` is necessary.

Generate a wireguard keypair using `wg`.

```sh
export CLIENT_PRIVATE_KEY="$(wg genkey)"
export CLIENT_PUBLIC_KEY="$(echo $CLIENT_PRIVATE_KEY | wg pubkey)"
```

Next, pick a free IP address from the `192.168.29.0/24` subnet, which is not already in the server config file;
to check the current server config file, open the google cloud console, go to secret manager, and view the 
latest version for the `maintenance-vm-wireguard-config` secret ([link](https://console.cloud.google.com/security/secret-manager/secret/maintenance-vm-wireguard-config/versions?project=broadcom-451918)).

The wireguard config will look like

```ini
[Interface]
PrivateKey = ...
Address = 192.168.29.1/24
ListenPort = 51820
PostUp = iptables -t nat -I POSTROUTING -o ens4 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o ens4 -j MASQUERADE

[Peer]
PublicKey = ...
AllowedIPs = 192.168.29.2/32

[Peer]
PublicKey = ...
AllowedIPs = 192.168.29.3/32
```

After picking a first free IP address, in the example above `192.168.29.4`:

```sh
export CLIENT_IP_ADDRESS="192.168.29.4"
```

Then generate a new peer entry for the server configuration by following script:

```sh
cat << EOF
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP_ADDRESS}/32

EOF
```

Then create new version of the `maintenance-vm-wireguard-config` by appending this entry at the end of the current value [here](https://console.cloud.google.com/security/secret-manager/secret/maintenance-vm-wireguard-config/versions?project=broadcom-451918).

Additionally, if the jumphost VM is up, you might want to add it to the wireguard configuration  in the current VM (it is also possible to recreate the jumphost VM, but this is going to change the wireguard enpoint also for other users).

```sh
gcloud compute ssh maintenance-jumphost --zone us-central1-f
sudo systemctl stop wg-quick@wg0
sudo vim /etc/wireguard/wg0.conf #Add your peer config
sudo systemctl start wg-quick@wg0
exit
```

The final step to setup wireguard is to generate a client configuration

```sh
cat << EOF > wg0.conf
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP_ADDRESS}/24
MTU = 1360

[Peer]
PublicKey = $(gcloud secrets versions access --secret maintenance-vm-wireguard-pubkey latest)
AllowedIPs = 192.168.31.0/24, 192.168.32.0/21
Endpoint = $(gcloud compute instances list --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --filter='name=maintenance-jumphost'):51820
PersistentKeepalive = 25
EOF
```

You can then either

- import this file to the wireguard UI (after this, you can remove the file from disk) and activate or deactivate the connection.
- use the file with the wireguard CLI e.g. `wg-quick up ~/wg0.conf`, and when finished `wg-quick down ~/wg0.conf`

## Additional settings

Generate `/etc/hosts` entries for vSphere and NSX; this is required to run the vSphere terraform scripts and it will also make the vSphere and NSX UI to work smootly.

```sh
gcloud vmware private-clouds describe k8s-gcp-gcve --location us-central1-a --format='json' | jq -r '.vcenter.internalIp + " " + .vcenter.fqdn +"\n" + .nsx.internalIp + " " + .nsx.fqdn'
```

Add those entries to `/etc/hosts`.