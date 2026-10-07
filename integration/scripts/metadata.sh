#!/bin/sh
# Metadata, network tags and service account scopes, read back from the
# instance's own metadata server. Labels are not exposed there, so they are
# asserted from the API side rather than here.
set -eu

MD="http://metadata.google.internal/computeMetadata/v1"
md() { curl -sf -H "Metadata-Flavor: Google" "${MD}/$1"; }

fail() { echo "FAIL: $*" >&2; exit 1; }

# The suite's own metadata key.
value=$(md instance/attributes/kitchen-integration)
echo "kitchen-integration=${value}"
[ "${value}" = "metadata-suite" ] ||
  fail "kitchen-integration metadata is '${value}', expected 'metadata-suite'"

# ...alongside, not instead of, the driver's own.
[ "$(md instance/attributes/created-by)" = "test-kitchen" ] ||
  fail "the driver's created-by metadata was lost"

tags=$(md instance/tags)
echo "tags=${tags}"
echo "${tags}" | grep -q "kitchen-metadata-suite" ||
  fail "the kitchen-metadata-suite network tag is missing"

# The driver expands short aliases such as storage-ro into full scope URLs.
scopes=$(md instance/service-accounts/default/scopes)
echo "scopes=${scopes}"
echo "${scopes}" | grep -q "https://www.googleapis.com/auth/devstorage.read_only" ||
  fail "the storage-ro alias did not expand to devstorage.read_only"
echo "${scopes}" | grep -q "https://www.googleapis.com/auth/logging.write" ||
  fail "the logging-write alias did not expand to logging.write"

echo "OK: metadata"
