#!/bin/bash

case "$1" in
        rpi3)
            UEFI_URL=https://github.com/pftf/RPi3/releases/download/v1.27/RPi3_UEFI_Firmware_v1.27.zip
            ;;
        rpi4)
            UEFI_URL=https://github.com/pftf/RPi4/releases/download/v1.13/RPi4_UEFI_Firmware_v1.13.zip
            ;;
        *)
            echo $"Usage: $0 {rpi3|rpi4}"
            exit 1
esac

PI_VERSION=$1
SRC_PATH=$PWD
BUILD_PATH=${SRC_PATH}/build
IMAGE_FILE=k3os-${PI_VERSION}.img
SD_CARD_SIZE=1024

K3OS_ROOTFS_URL=https://github.com/rancher/k3os/releases/download/v0.10.3/k3os-rootfs-arm64.tar.gz
GRUB_ARM64_DEB_URL=http://ftp.debian.org/debian/pool/main/g/grub2/grub-efi-arm64-bin_2.04-8_arm64.deb
GRUB_ARM64_SIGNED_DEB_URL=http://ftp.debian.org/debian/pool/main/g/grub-efi-arm64-signed/grub-efi-arm64-signed_1+2.04+8_arm64.deb

# setup build location

BUILD_CACHE_PATH=${BUILD_PATH}/cache && mkdir -p ${BUILD_CACHE_PATH}
BUILD_IMAGE_PATH=${BUILD_PATH}/image && mkdir -p ${BUILD_IMAGE_PATH}
BUILD_MOUNT_PATH=${BUILD_PATH}/mount && mkdir -p ${BUILD_MOUNT_PATH}

# create image file

IMAGE=${BUILD_IMAGE_PATH}/${IMAGE_FILE}
dd if=/dev/zero of=${IMAGE} bs=1MiB count=${SD_CARD_SIZE}
DEVICE=$(losetup -f --show ${IMAGE})
echo "Image ${IMAGE} created and mounted as ${DEVICE}."

# partition and format image file

parted -s ${DEVICE} mklabel msdos
parted -s ${DEVICE} mkpart primary fat16 0% 50MB
parted -s ${DEVICE} mkpart primary ext4 50MB 100%
parted -s ${DEVICE} set 1 boot on
PART_ESP=${DEVICE}p1
PART_STATE=${DEVICE}p2

mkfs.vfat -F 16 ${PART_ESP}
fatlabel ${PART_ESP} K3OS_ESP
mkfs.ext4 -F -L K3OS_STATE ${PART_STATE}

# mount partitions

TARGET=${BUILD_MOUNT_PATH}/k3os_state
mkdir -p ${TARGET}
mount ${PART_STATE} ${TARGET}
mkdir -p ${TARGET}/boot/efi
mkdir -p ${TARGET}/boot/grub
mount ${PART_ESP} ${TARGET}/boot/efi

# Unpack k3os root filesystem to ${TARGET}

curl -sfL ${K3OS_ROOTFS_URL} | tar -zxvf - --strip-components=1 -C ${TARGET}

# Customize k3os

# cp ${SRC_PATH}/state/* ${TARGET}/k3os/system/
mv ${TARGET}/k3os/system/config.yaml ${TARGET}/k3os/system/_config.yaml
ln -s /media/mmcblk0p1/config.yaml ${TARGET}/k3os/system/config.yaml

# Unpack Rpi UEFI to ${TARGET}/boot/efi

TEMP_FILE=${BUILD_CACHE_PATH}/$(mktemp rpiuefi.XXXXXXXX.zip)
curl -o ${TEMP_FILE} -fL ${UEFI_URL}
unzip ${TEMP_FILE} -d ${TARGET}/boot/efi
rm -f $TEMP_FILE

# Customize UEFI

cp ${SRC_PATH}/boot/* ${TARGET}/boot/efi

# Unpack and install GRUB

TEMP_GRUB=${BUILD_CACHE_PATH}/grub && mkdir -p ${TEMP_GRUB}

TEMP_FILE=${BUILD_CACHE_PATH}/$(mktemp grubarm64.XXXXXXXX.deb)
curl -o ${TEMP_FILE} -fL ${GRUB_ARM64_DEB_URL}
cd ${BUILD_CACHE_PATH} && ar x ${TEMP_FILE} data.tar.xz && cd ${SRC_PATH}
tar xvf ${BUILD_CACHE_PATH}/data.tar.xz --strip-components=1 -C ${TEMP_GRUB}
rm -f ${BUILD_CACHE_PATH}/data.tar.xz
rm -f ${TEMP_FILE}

TEMP_FILE=${BUILD_CACHE_PATH}/$(mktemp grubarm64-signed.XXXXXXXX.deb)
curl -o ${TEMP_FILE} -fL ${GRUB_ARM64_SIGNED_DEB_URL}
cd ${BUILD_CACHE_PATH} && ar x ${TEMP_FILE} data.tar.xz && cd ${SRC_PATH}
tar xvf ${BUILD_CACHE_PATH}/data.tar.xz --strip-components=1 -C ${TEMP_GRUB}
rm -f ${BUILD_CACHE_PATH}/data.tar.xz
rm -f ${TEMP_FILE}

cat > ${TARGET}/boot/grub/grub.cfg << EOF
set default=0
set timeout=10
set gfxmode=auto
set gfxpayload=keep
insmod all_video
insmod gfxterm
menuentry "k3OS Current" {
  search.fs_label K3OS_STATE root
  set sqfile=/k3os/system/kernel/current/kernel.squashfs
  loopback loop0 /\$sqfile
  set root=(\$root)
  linux (loop0)/vmlinuz printk.devkmsg=on console=tty1 $GRUB_DEBUG
  initrd /k3os/system/kernel/current/initrd
}
menuentry "k3OS Previous" {
  search.fs_label K3OS_STATE root
  set root=(\$root)
  linux /k3os/system/kernel/previous/vmlinuz printk.devkmsg=on console=tty1 $GRUB_DEBUG
  initrd /k3os/system/kernel/previous/initrd
}
menuentry "k3OS Rescue Shell" {
  search.fs_label K3OS_STATE root
  set root=(\$root)
  linux /k3os/system/kernel/current/vmlinuz printk.devkmsg=on rescue console=tty1
  initrd /k3os/system/kernel/current/initrd
}
EOF

grub-install --directory=${TEMP_GRUB}/usr/lib/grub/arm64-efi --boot-directory=${TARGET}/boot --efi-directory=${TARGET}/boot/efi --uefi-secure-boot --bootloader-id=debian --removable

# un-mount partitions

umount ${TARGET}/boot/efi || true
umount ${TARGET} || true

# compress image file

gzip ${IMAGE}
