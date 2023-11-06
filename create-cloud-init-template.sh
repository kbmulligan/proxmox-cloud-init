#!/bin/bash

VM_DISTRO="ubuntu-2204"

DISTRO_NAME="jammy"
RELEASE="release-20231030"
TARGET_IMAGE="ubuntu-22.04-minimal-cloudimg-amd64.img"
DISTRO_BASE_URL="https://cloud-images.ubuntu.com/minimal/releases"

VM_ID=899
VM_NAME=ci-testing
VM_DISK_SIZE="32G"

# password is hashed with the following
# $(openssl passwd -5 $CLEAR_TEXT_PASSWORD)
PASSWORD_HASH="---"


STORAGE_DEST="local-lvm"

VM_DISK_URL="${DISTRO_BASE_URL}/${DISTRO_NAME}/${RELEASE}/${TARGET_IMAGE}"
CHECKSUMS="${DISTRO_BASE_URL}/${DISTRO_NAME}/${RELEASE}/SHA256SUMS"

EXTENSION=".qcow2"
DISK_FILENAME="${VM_DISTRO}-cloud-image${EXTENSION}"

echo "Starting cloud-init image creation for $DISTRO_NAME $RELEASE as VM ID: $VM_ID ..."

if [ ! -f $TARGET_IMAGE ]; then
    # download and configure image
    echo 'Downloading...'
    #curl -fsSL -o $TARGET_IMAGE $VM_DISK_URL
    curl -fSL -o $TARGET_IMAGE $VM_DISK_URL
else
    echo 'File already present!'
fi

# verify checksums here
curl -fsSL $CHECKSUMS | grep $TARGET_IMAGE > ./checksum

# echo "Checksum should be: $(cat ./checksum)"
# echo "Checksum is       : $(shasum -a 256 $TARGET_IMAGE)"
# shasum -a 256 -b -c checksum ubuntu-22.04-minimal-cloudimg-amd64.img

echo "Proper checksum verification ..."
# exit value will be 0 if all is good
shasum -a 256 -b -c checksum
check_result=$?
if [ $check_result != '0' ]; then
    echo $check_result
    echo 'Checksum did not check out!'
    echo 'Take a closer look at that before continuing...'
    exit 1
else
    echo 'Checksum OK'
fi
rm ./checksum

# copy over to new name
cp $TARGET_IMAGE $DISK_FILENAME

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

qm set $VM_ID --scsi0 local-lvm:vm-$VM_ID-disk-0,size=$VM_DISK_SIZE

# actually we may want to set the cloud init stuff in cloud.cfg directly
# ... but this could be an option
qm set $VM_ID --ide2 local-lvm:cloudinit


# optional, but nice to have
qm set $VM_ID --tags ubuntu-2204,cloudinit

# pve cloud-init options
qm set $VM_ID --ciuser sysadmin
# qm set $VM_ID --cipassword $PASSWORD_HASH        # $(openssl passwd -5 $CLEAR_TEXT_PASSWORD)
qm set $VM_ID --cipassword --------

# set network
qm set $VM_ID --ipconfig0 ip=dhcp


# CONVERT TO TEMPLATE -- maybe don't want this if it's going to be created here anyway
# qm template $VM_ID

echo 'Letting VM create itself now ...'
sleep 15

echo 'Starting VM now ...'
qm start $VM_ID
