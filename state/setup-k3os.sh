#!/bin/bash

# resize K3OS_STATE partition to maximum available space

PART_START=$(cat /sys/block/mmcblk0/mmcblk0p2/start)
PART_END=$(($PART_START+$(cat /sys/block/mmcblk0/mmcblk0p2/size)))
PART_NEWEND=$(($(cat /sys/block/mmcblk0/size)-8))

if [ "$PART_NEWEND" -gt "$PART_END" ]
then
  echo "Resizing partition '/dev/mmcblk0p2' on '/dev/mmcblk0'"
  parted /dev/mmcblk0 ---pretend-input-tty <<EOF
resizepart
2
Yes
100%
quit
EOF
  resize2fs /dev/mmcblk0p2
  echo "Done"
fi

# create mount point for efi partition

mkdir -p /media/mmcblk0p1

# link configuration file from efi partition

ln -s /media/mmcblk0p1/config.yaml /var/lib/rancher/k3os/config.yaml



# mount efi boot partition

# echo "Mounting UEFI partition"
# mkdir -p /media/mmcblk0p1
# mount /dev/mmcblk0p1 /media/mmcblk0p1

# Linking config.yaml to boot partition

# echo "Linking config.yaml"
# ln -s /media/mmcblk0p1/config.yaml /var/lib/rancher/k3os/config.yaml


# replace configuration with our own

# echo "Replacing config.yaml"
# cp /media/mmcblk0p1/config.yaml /var/config.yaml

