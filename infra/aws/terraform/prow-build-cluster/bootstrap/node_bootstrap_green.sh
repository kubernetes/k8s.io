# Copyright 2023 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## intended to be used as a node pre-bootstrap script
## based on: https://github.com/awslabs/amazon-eks-ami/pull/1171

# We're intentionally disabling SC2148 because we don't need shebang here.
# This script is integrated as part of another script that already includes it.
# shellcheck disable=SC2148

set -o errexit
set -o nounset
set -o pipefail

## sysctl settings (required by Prow to avoid inotify issues)
sysctl -w fs.inotify.max_user_watches=1048576
sysctl -w fs.inotify.max_user_instances=8192

## Set up ephemeral disks (SSDs) to be used by containerd and kubelet

MNT_DIR="/mnt/k8s-disks"

# Pick the first NVMe disk. In this case, we care about only one disk,
# additional disks are not much of use for us.
# We don't want to deal with RAID because we don't gain much from it.
disk=$(find -L /dev/disk/by-id/ -xtype l -name '*NVMe_Instance_Storage_*' | head -n 1)

if [[ -z "${disk}" ]]; then
  echo "no ephemeral disks found, skipping disk setup"
  exit 0
fi

# Get devices of NVMe instance storage ephemeral disks
dev=$(realpath "${disk}")

# Mounts and creates xfs file systems on chosen EC2 instance store NVMe disk
# without existing file system. Mounts in /mnt/k8s-disks
if [[ -z "$(lsblk "${dev}" -o fstype --noheadings)" ]]; then
  mkfs.xfs -l su=8b "${dev}"
fi

if [[ -n "$(lsblk "${dev}" -o MOUNTPOINT --noheadings)" ]]; then
  echo "${dev} is already mounted."
  exit 0
fi

# Get mount point for the disk.
mount_point="${MNT_DIR}"
mount_unit_name="$(systemd-escape --path --suffix=mount "${mount_point}")"

mkdir -p "${mount_point}"

# Create systemd service to mount the disk.
cat > "/etc/systemd/system/${mount_unit_name}" << EOF
[Unit]
Description=Mount EC2 Instance Store NVMe disk
[Mount]
What=${dev}
Where=${mount_point}
Type=xfs
Options=defaults,noatime
[Install]
WantedBy=multi-user.target
EOF

systemd-analyze verify "${mount_unit_name}"
systemctl enable "${mount_unit_name}" --now

## Create mount points on SSD for containerd and kubelet
needs_linked=""

# Stop containerd and kubelet if they are running.
for unit in "containerd" "kubelet"; do
  if [[ "$(systemctl is-active var-lib-${unit}.mount)" != "active" ]]; then
    needs_linked+=" ${unit}"
  fi
done

systemctl stop containerd.service snap.kubelet-eks.daemon.service

# Transfer state directories to the disk, if they exist.
for unit in ${needs_linked}; do
  var_lib_mount_point="/var/lib/${unit}"
  unit_mount_point="${mount_point}/${unit}"

  echo "Copying ${var_lib_mount_point}/ to ${unit_mount_point}/"
  cp -a "${var_lib_mount_point}/" "${unit_mount_point}/"
  
  mount_unit_name="$(systemd-escape --path --suffix=mount "${var_lib_mount_point}")"
  
  cat > "/etc/systemd/system/${mount_unit_name}" << EOF
    [Unit]
    Description=Mount ${unit} on EC2 Instance Store NVMe disk
    [Mount]
    What=${unit_mount_point}
    Where=${var_lib_mount_point}
    Type=none
    Options=bind
    [Install]
    WantedBy=multi-user.target
EOF
  systemd-analyze verify "${mount_unit_name}"
  systemctl enable "${mount_unit_name}" --now
done

# Start again stopped services.
systemctl start containerd.service snap.kubelet-eks.daemon.service

# Install rsyslog
apt update
apt install rsyslog -y
