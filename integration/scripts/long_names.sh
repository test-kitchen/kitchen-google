#!/bin/sh
# The suite and disk names together overflow the 63 characters GCE allows, so
# the driver must fall back to a UUID-based instance name -- and must still
# leave room for "<instance>-data-disk-long-enough" to be a legal disk name.
set -eu

MD="http://metadata.google.internal/computeMetadata/v1"
md() { curl -sf -H "Metadata-Flavor: Google" "${MD}/$1"; }

fail() { echo "FAIL: $*" >&2; exit 1; }

name=$(md instance/name)
echo "instance=${name} (${#name} characters)"

[ "${#name}" -le 63 ] || fail "instance name is ${#name} characters, GCE allows 63"
echo "${name}" | grep -Eq '^[a-z]([-a-z0-9]*[a-z0-9])?$' ||
  fail "instance name '${name}' is not a legal GCE resource name"

# The suite name cannot fit, so the driver should have used tk-<uuid>.
echo "${name}" | grep -Eq '^tk-[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' ||
  fail "expected a tk-<uuid> fallback name, got '${name}'"

# ...and the disk named after it has to have been created and attached.
root_dev=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")
lsblk -bdn -o NAME,SIZE | awk -v root="${root_dev}" '$1 != root' | grep -q . ||
  fail "the extra disk was not attached"

echo "OK: long-instance-and-disk-names"
