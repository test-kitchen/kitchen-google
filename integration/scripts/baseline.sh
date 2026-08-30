#!/bin/sh
# The path every suite depends on: the instance exists, the driver's own
# metadata reached it, and it is reachable over the transport the driver
# handed to Test Kitchen. Running at all proves the last of those.
set -eu

MD="http://metadata.google.internal/computeMetadata/v1"
md() { curl -sf -H "Metadata-Flavor: Google" "${MD}/$1"; }

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "OK: $*"; }

name=$(md instance/name)
zone=$(md instance/zone | awk -F/ '{print $NF}')
echo "instance=${name} zone=${zone}"

[ -n "${name}" ] || fail "the metadata server reported no instance name"

# Set by the driver on every instance, whatever the suite asks for.
[ "$(md instance/attributes/created-by)" = "test-kitchen" ] ||
  fail "created-by metadata is not test-kitchen"

md instance/attributes/test-kitchen-instance >/dev/null ||
  fail "test-kitchen-instance metadata is missing"
md instance/attributes/test-kitchen-user >/dev/null ||
  fail "test-kitchen-user metadata is missing"

# The user metadata carrying the SSH key has to survive the merge with the
# driver's own keys -- GCE rejects an instance that is sent a key twice.
md instance/attributes/ssh-keys >/dev/null ||
  fail "the ssh-keys metadata this suite set did not reach the instance"

ok "baseline"
