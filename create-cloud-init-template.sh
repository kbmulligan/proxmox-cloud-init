#!/bin/bash

VM_ID=899
VM_NAME=template-pipeline
VM_DISTRO="ubuntu-2204"
VM_DISK_SIZE="32G"

STORAGE_DEST="local-lvm"

VM_DISK_URL="https://cloud-images.ubuntu.com/minimal/releases/jammy/release-20231030/ubuntu-22.04-minimal-cloudimg-amd64.img"
CHECKSUMS="https://cloud-images.ubuntu.com/minimal/releases/jammy/release/SHA256SUMS"

EXTENSION=".qcow2"
DISK_FILENAME="${VM_DISTRO}-cloud-image${EXTENSION}"

# download and configure image
curl -fsSL -o $DISK_FILENAME $VM_DISK_URL

# verify checksums here
echo 'Checksum should be:'
curl -fsSL $CHECKSUMS | grep "amd64.img"
echo 'Checksum is       :'
shasum -a 256 $DISK_FILENAME

# make cloud changes to the disk here
echo 'Copy in our custom cloud-init config...'
cp ./${VM_DISTRO}-cloud.cfg ./cloud.cfg
virt-copy-in -a $DISK_FILENAME ./cloud.cfg /etc/cloud/
rm ./cloud.cfg

qemu-img resize $DISK_FILENAME $VM_DISK_SIZE

# CREATE VM
qm create $VM_ID \
  --agent 1 \
  --name $VM_NAME \
  --cpu x86-64-v2-AES \
  --memory 1024 \
  --numa 1 \
  --ostype l26 \
  --scsihw virtio-scsi-pci \
  --net0 model=virtio,bridge=vmbr0 \
  --boot order=scsi0 \
  --citype nocloud \
  --ide0 none,media=cdrom


# create display serial port connection
qm set $VM_ID --serial0 socket --vga serial0


qm importdisk $VM_ID $DISK_FILENAME $STORAGE_DEST

qm set $VM_ID --scsi0 local-lvm:vm-$VM_ID-disk-0,iothread=1,size=$VM_DISK_SIZE

# actually we want to set the cloud init stuff in cloud.cfg directly
# qm set $VM_ID --ide2 local-lvm:cloudinit
