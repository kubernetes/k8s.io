#!/usr/bin/env bash

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

set -o errexit
set -o nounset
set -o pipefail

ROOT_DIR="/.bottlerocket/rootfs"
MNT_DIR="${ROOT_DIR}/mnt/k8s-disks"

mkdir -p "${MNT_DIR}"

## Increase vm.min_free_kbytes from 67584 to 540672 as recommend by the AWS support
## to try to mitigate https://github.com/kubernetes/k8s.io/issues/5473
## The general guidance for the vm.min_free_kbytes parameter is to not have it exceed 5%
## of the total system memory which in the case of an r5d.4xlarge would be about 6400MB.
## For the sake of testing, let's increase this value from 67584 to 540672 (a 8x increase)
## to bring this up to about 540MB.
echo 540672 > ${ROOT_DIR}/proc/sys/vm/min_free_kbytes

## Set up ephemeral disk (SSD) to be used by containerd and kubelet

# Pick the first NVMe disk. In this case, we care about only one disk,
# additional disks are not much of use for us.
# We don't want to deal with RAID because we don't gain much from it.
disk=$(find -L "${ROOT_DIR}/dev/disk/by-id/" -xtype l -name '*NVMe_Instance_Storage_*' | head -n 1)

if [[ -z "${disk}" ]]; then
  echo "no ephemeral disks found, skipping disk setup"
  exit 0
fi

# Get device of NVMe instance storage ephemeral disks
dev=$(realpath "${disk}")

# Mount and create xfs file systems on chosen EC2 instance store NVMe disk
# without existing file system
if [[ -z "$(lsblk "${dev}" -o fstype --noheadings)" ]]; then
  mkfs.xfs -l su=8b "${dev}"
fi

if [[ -n "$(lsblk "${dev}" -o MOUNTPOINT --noheadings)" ]]; then
  echo "${dev} is already mounted."
  exit 0
fi

# Mount the disk in /mnt/k8s-disks
mount -t xfs -o defaults,noatime "${dev}" "${MNT_DIR}"

# Mount containerd and kubelet directories to /mnt/k8s-disks
for unit in containerd kubelet ; do
  mkdir -p "${MNT_DIR}/${unit}"
  mount --rbind "${MNT_DIR}/${unit}" "${ROOT_DIR}/var/lib/${unit}"
  mount --make-rshared "${ROOT_DIR}/var/lib/${unit}"
done
