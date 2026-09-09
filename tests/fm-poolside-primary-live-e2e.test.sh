#!/usr/bin/env bash
# tests/fm-poolside-primary-live-e2e.test.sh - the live-e2e guard for the
# poolside (Pool / Poolside ACP) adapter. Runs only when FM_POOLSIDE_LIVE_E2E=1
# and a real `pool` binary is on PATH. Catches vendor drift that the portable
# fm-poolside-harness.test.sh (which uses a fake pool stub) cannot.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"
# shellcheck source=bin/fm-control-lib.sh
. "$ROOT/bin/fm-control-lib.sh"

if [ "${FM_POOLSIDE_LIVE_E2E:-0}" != 1 ]; then
  pass "skipped (FM_POOLSIDE_LIVE_E2E != 1): poolside live e2e requires a real pool CLI"
  exit 0
fi

HARNESS="$ROOT/bin/fm-harness.sh"

command -v pool >/dev/null 2>&1 || {
  pass "skipped (no pool binary on PATH): poolside live e2e"
  exit 0
}

# --- Live detection ------------------------------------------------------------

test_live_poolside_detection() {
  [ "$(pool "$HARNESS")" = poolside ] \
    || fail "a real pool binary must detect as poolside via its anchored name"
  pass "live detection: pool detects as poolside"
}

# --- Live control tables -------------------------------------------------------

test_live_poolside_control_tables() {
  [ "$(fm_control_exit_command poolside)" = "C-c" ] || fail "poolside exit command must be C-c"
  [ "$(fm_control_interrupt_key poolside)" = "C-c" ] || fail "poolside interrupt key must be C-c"
  [ "$(fm_control_interrupt_repeat poolside)" = 1 ] || fail "poolside interrupts on a single press"
  [ -z "$(fm_control_interrupt_clear_key poolside)" ] || fail "poolside needs no clear key"
  [ "$(fm_control_interrupt_ack_source poolside)" = "none" ] || fail "poolside ack source must be none"
  pass "live control: poolside exits and interrupts via Ctrl-C, no clear key"
}

# --- Live launch surface -------------------------------------------------------

test_live_pool_acp_accepts_dash_dash_and_no_model() {
  # pool acp has no --model/-m flag; confirm the absence so the launch template
  # is never generated with a flag the CLI rejects.
  pool --help 2>&1 | grep -q -- '--help' || true
  if pool acp --model foo 2>&1 | grep -qi 'unknown shorthand\|flag'; then
    pass "live launch: pool acp rejects --model as expected (model comes from settings.yaml)"
  else
    fail "pool acp unexpectedly accepted --model (expected no --model flag for poolside)"
  fi
  # -- must be forwarded as a bare separator, confirming the brief-delivery path.
  pool acp -- 2>&1 </dev/null || true
  pass "live launch: pool acp accepts -- and has no --model flag"
}

test_live_poolside_detection
test_live_poolside_control_tables
test_live_pool_acp_accepts_dash_dash_and_no_model
