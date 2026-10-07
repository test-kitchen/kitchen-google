#!/bin/sh
# Local SSDs are attached as SCRATCH disks with no size and no source image,
# which is the one disk shape the driver must not send a disk_size for. GCE
# fixes them at 375 GB.
set -eu

root_dev=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")
echo "root device: ${root_dev}"
lsblk -bdn -o NAME,SIZE

scratch=$(lsblk -bdn -o NAME,SIZE |
  awk -v root="${root_dev}" '$1 != root { gb = $2 / 1000 / 1000 / 1000; if (gb >= 370 && gb <= 380) print $1 }' |
  head -1)

[ -n "${scratch}" ] ||
  { echo "FAIL: no 375 GB scratch disk is attached" >&2; exit 1; }

echo "OK: local-ssd ${scratch}"
