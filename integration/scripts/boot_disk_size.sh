#!/bin/sh
# Two suites share this script:
#
#   legacy-disk    asks for a 20 GB boot disk through the deprecated top-level
#                  disk_size option.
#   boot-disk-size asks for 10 GB from a 20 GB image, which GCE would refuse,
#                  so the driver has to raise the request to the image's size.
#
# Either way the boot disk has to come out at 20 GB or more.
set -eu

root_dev=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")
boot_gb=$(( $(lsblk -bdn -o SIZE "/dev/${root_dev}") / 1000 / 1000 / 1000 ))
echo "boot device ${root_dev} is ${boot_gb} GB"

[ "${boot_gb}" -ge 20 ] ||
  { echo "FAIL: boot disk is ${boot_gb} GB, expected at least 20" >&2; exit 1; }

echo "OK: boot-disk-size ${boot_gb}GB"
