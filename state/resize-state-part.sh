#!/bin/bash

# resize K3OS_STATE partition to maximum

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
