#!/bin/bash

set -eu

echo "Patching VM with name $1 for aarch64 emulation"
vm_id="$(qm list | awk "/$1/ {print \$1}")"
echo "Found VMID $vm_id"

config="/etc/pve/qemu-server/$vm_id.conf"

# Step 1: Comment out vmgenid, cpu, efidisk line which prevents boot
sed -i '/^vmgenid:/s/^/#/' "$config"
sed -i '/^cpu:/s/^/#/' "$config"
sed -i '/^efidisk0/s/^/#/' "$config" # this causes a warning but boots

# Step 2: Set serial console for display
qm set "$vm_id" --serial0=socket
qm set "$vm_id" --vga=serial0

# Step 3: Add the correct arch type
arch_line="arch: aarch64"
grep -qF -- "$arch_line" "$config" || echo "$arch_line" >>"$config"

# See discussion: https://forum.proxmox.com/threads/uefi-pxe-boot-issues-after-upgrading-from-proxmox-ve-8-3-4-to-8-3-5.164468/
# Step 4: Add RNG, without this EDK2's EFI network stack won't work for "security" reasons
rng_line="args: -object 'rng-random,filename=/dev/urandom,id=rng0' -device 'virtio-rng-pci,rng=rng0,max-bytes=1024,period=1000,bus=pcie.0,addr=0x1d'"
grep -qF -- "$rng_line" "$config" || echo "$rng_line" >>"$config"
