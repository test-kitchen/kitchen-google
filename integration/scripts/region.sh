#!/bin/sh
# The suite configures a region and no zone, so the driver had to list the
# region's zones and pick one that was up. Assert it landed in that region.
#
# The expectation travels as instance metadata rather than as an environment
# variable: the provisioner runs the script on the instance, where nothing of
# the local environment survives.
set -eu

MD="http://metadata.google.internal/computeMetadata/v1"
md() { curl -sf -H "Metadata-Flavor: Google" "${MD}/$1"; }

expected_region=$(md instance/attributes/kitchen-expected-region)
zone=$(md instance/zone | awk -F/ '{print $NF}')
echo "zone=${zone} expected_region=${expected_region}"

[ -n "${expected_region}" ] ||
  { echo "FAIL: kitchen-expected-region metadata is missing" >&2; exit 1; }

# us-central1-a -> us-central1
region=$(echo "${zone}" | sed 's/-[a-z]$//')

[ "${region}" = "${expected_region}" ] ||
  { echo "FAIL: instance is in region ${region}, not ${expected_region}" >&2; exit 1; }

echo "OK: region"
