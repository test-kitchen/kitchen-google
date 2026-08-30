#!/bin/sh
# A standalone persistent disk, created before the instance and attached to it.
# The driver takes a completely different path for these than for a disk
# created inline with the instance, including waiting for READY and recording
# the name so a later destroy can find it.
set -eu

fail() { echo "FAIL: $*" >&2; exit 1; }

root_dev=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")
echo "root device: ${root_dev}"

# Sizes in whole gigabytes, keyed by device name.
lsblk -bdn -o NAME,SIZE | while read -r dev bytes; do
  echo "  ${dev} $((bytes / 1000 / 1000 / 1000)) GB"
done

boot_gb=$(( $(lsblk -bdn -o SIZE "/dev/${root_dev}") / 1000 / 1000 / 1000 ))
[ "${boot_gb}" -ge 15 ] || fail "boot disk is ${boot_gb} GB, expected 15"

data_gb=$(lsblk -bdn -o NAME,SIZE |
  awk -v root="${root_dev}" '$1 != root { printf "%d\n", $2 / 1000 / 1000 / 1000 }' |
  sort -rn | head -1)

[ -n "${data_gb}" ] || fail "no disk was attached other than the boot disk"
[ "${data_gb}" -ge 25 ] || fail "extra disk is ${data_gb} GB, expected 25"

echo "OK: extra-disk boot=${boot_gb}GB data=${data_gb}GB"
