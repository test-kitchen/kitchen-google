#!/bin/sh
# A preemptible instance can neither live-migrate nor auto-restart. The suite
# asks for both anyway, so this also covers the driver overriding them.
set -eu

MD="http://metadata.google.internal/computeMetadata/v1"
md() { curl -sf -H "Metadata-Flavor: Google" "${MD}/$1"; }

fail() { echo "FAIL: $*" >&2; exit 1; }

preemptible=$(md instance/scheduling/preemptible)
restart=$(md instance/scheduling/automatic-restart)
maintenance=$(md instance/scheduling/on-host-maintenance)
echo "preemptible=${preemptible} automatic-restart=${restart} on-host-maintenance=${maintenance}"

[ "${preemptible}" = "TRUE" ] || fail "the instance is not preemptible"
[ "${restart}" = "FALSE" ] || fail "auto_restart was not forced off"
[ "${maintenance}" = "TERMINATE" ] || fail "on-host-maintenance is not TERMINATE"

echo "OK: preemptible"
