#!/bin/bash

# resize K3OS_STATE partition to maximum available space

PART_START=$(cat /sys/block/mmcblk0/mmcblk0p2/start)
PART_END=$(($PART_START+$(cat /sys/block/mmcblk0/mmcblk0p2/size)))
PART_NEWEND=$(($(cat /sys/block/mmcblk0/size)-8))

if [ "$PART_NEWEND" -gt "$PART_END" ]
then
  echo "Resizing STATE partition"
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

# mount efi partition

echo "Mounting UFI partition"
mkdir -p /media/mmcblk0p1
mount /dev/mmcblk0p1 /media/mmcblk0p1 || true
ln -s  /media/mmcblk0p1/k3os/config /var/lib/rancher/k3os/config.d || true
