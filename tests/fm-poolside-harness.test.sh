#!/usr/bin/env bash
# tests/fm-poolside-harness.test.sh - the portable regression for the poolside
# (Pool / Poolside ACP) adapter: detection, the FM_POOLSIDE_HARNESS precedence
# marker, session-lock identity, tmux liveness classification, the spawn launch
# line, and the per-task control tables.
#
# poolside's identity, launch, and lifecycle checks are HARNESS-DEPENDENT: their
# verdicts come from what the vendor emits (a process name, a CLI flag surface).
# This suite pins the LOGIC with a fake pool binary (a symlink to bash), a plain
# throwaway home, and FM_FAKE_LAUNCH_LOG, so CI enforces it with no pool CLI
# installed; FM_POOLSIDE_LIVE_E2E=1 tests/fm-poolside-primary-live-e2e.test.sh
# is the live guard that catches vendor drift against a real pool.
#
# The load-bearing contracts:
#   1. pool publishes no harness-identity env marker of its own (only HERDR_*
#      vars from the backend), so detection is by the anchored process name
#      `pool` in the ancestry walk. spool, pull, and similar commands never
#      identify.
#   2. FM_POOLSIDE_HARNESS=poolside is a firstmate-owned precedence override
#      that beats an inherited CLAUDECODE only when a `pool` process is
#      genuinely in the ancestry; it is inert when it leaks into a worker
#      whose ancestry holds no pool.
#   3. Every poolside launch clears foreign markers, sets FM_POOLSIDE_HARNESS,
#      invokes `pool acp`, and delivers the brief via the canonical
#      `encode launch-brief` envelope — with NO --model flag, because
#      `pool acp` reads its model from ~/.config/poolside/settings.yaml.
#   4. A harness with no --model flag keeps the model in metadata only.
#   5. poolside exits and interrupts via Ctrl-C (send_key, not text_submit),
#      and has no wiring paths or turnend token files.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

# shellcheck source=bin/fm-control-lib.sh
. "$ROOT/bin/fm-control-lib.sh"
# shellcheck source=bin/fm-session-lock-lib.sh
. "$ROOT/bin/fm-session-lock-lib.sh"

HARNESS="$ROOT/bin/fm-harness.sh"
TMP_ROOT=$(fm_test_tmproot fm-poolside-harness)

# A process whose kernel-recorded identity is the bare name `pool`: a SYMLINK to
# the system shell, never a copied binary (a copied platform binary fails macOS
# code signing). macOS reports the symlink name through `ps -o comm=`, which is
# the exact signal under test. The `-c` body ends in a no-op so bash does not
# exec-optimize the single command away and replace the named process.
make_named_pool() {  # <dir> -> echoes <bindir>
  local dir=$1
  mkdir -p "$dir"
  ln -sf /bin/bash "$dir/pool"
  printf '%s' "$dir"
}

# --- 1. Detection --------------------------------------------------------------

test_detection_anchored_name_and_marker_precedence() {
  local bin out TEST_IN_POOL_TREE
  bin=$(make_named_pool "$TMP_ROOT/named")
  # shellcheck disable=SC2016 # the quoted body expands inside the named shell
  out=$(env -u CLAUDECODE -u FM_POOLSIDE_HARNESS -u PI_CODING_AGENT -u GROK_AGENT -u GEMINI_CLI -u CURSOR_AGENT -u CURSOR_INVOKED_AS \
    "$bin/pool" -c '"$1"; :' _ "$HARNESS")
  [ "$out" = poolside ] || fail "a process named pool must detect as poolside, got '$out'"
  # The marker beats an inherited CLAUDECODE only under a real pool ancestor.
  # shellcheck disable=SC2016 # the quoted body expands inside the named shell
  out=$(env -u PI_CODING_AGENT -u GROK_AGENT -u GEMINI_CLI -u CURSOR_AGENT -u CURSOR_INVOKED_AS CLAUDECODE=1 FM_POOLSIDE_HARNESS=poolside \
    "$bin/pool" -c '"$1"; :' _ "$HARNESS")
  [ "$out" = poolside ] || fail "FM_POOLSIDE_HARNESS under a pool ancestor must outrank an inherited CLAUDECODE, got '$out'"
  # Decoys whose name merely contains 'pool' must not identify, and a leaked
  # marker must be inert in a non-pool worker. Both require that the test
  # runner itself is NOT inside a pool ancestry: a real inherited pool ancestor
  # makes decoys and leaked markers resolve through that ancestor rather than
  # their own name or lack of marker. CI never runs inside pool, so these
  # branches are always exercised there.
  TEST_IN_POOL_TREE=$("$HARNESS" 2>/dev/null)
  if [ "$TEST_IN_POOL_TREE" = poolside ]; then
    pass "fm-harness: pool detects as poolside; decoys/inert skipped (test runner is inside a pool ancestry — always run in CI)"
    return
  fi
  # Decoys whose name merely contains 'pool' must not identify.
  for decoy in spool pull; do
    ln -sf /bin/bash "$bin/$decoy"
    # shellcheck disable=SC2016 # the quoted body expands inside the named shell
    out=$(env -u CLAUDECODE -u FM_POOLSIDE_HARNESS -u PI_CODING_AGENT -u GROK_AGENT -u GEMINI_CLI -u CURSOR_AGENT -u CURSOR_INVOKED_AS \
      "$bin/$decoy" -c '"$1"; :' _ "$HARNESS")
    [ "$out" != poolside ] || fail "'$decoy' merely contains 'pool' and must not detect as poolside"
  done
  # ...and is inert when it leaks into a worker with no pool ancestor.
  # shellcheck disable=SC2016 # the quoted body expands inside the named shell
  out=$(env -u PI_CODING_AGENT -u GROK_AGENT -u GEMINI_CLI -u CURSOR_AGENT -u CURSOR_INVOKED_AS CLAUDECODE=1 FM_POOLSIDE_HARNESS=poolside \
    bash -c '"$1"; :' _ "$HARNESS")
  [ "$out" = claude ] || fail "a leaked FM_POOLSIDE_HARNESS without a pool ancestor must not relabel a claude worker, got '$out'"
  pass "fm-harness: pool detects as poolside by its anchored name; the marker is a precedence override needing real pool ancestry"
}

# --- 2. Control tables ---------------------------------------------------------

test_control_tables() {
  [ "$(fm_control_exit_command poolside)" = "C-c" ] || fail "poolside exit command must be C-c"
  [ "$(fm_control_interrupt_key poolside)" = "C-c" ] || fail "poolside interrupt key must be C-c"
  [ "$(fm_control_interrupt_repeat poolside)" = 1 ] || fail "poolside interrupts on a single press"
  [ -z "$(fm_control_interrupt_clear_key poolside)" ] || fail "poolside leaves its composer empty and needs no clear key"
  [ "$(fm_control_interrupt_ack_source poolside)" = "none" ] || fail "poolside interrupt ack source must be none"
  [ "$(fm_control_harness_family poolside)" = "poolside" ] || fail "poolside family must be poolside"
  [ -z "$(fm_control_harness_wiring_paths poolside /wt /st id1)" ] || fail "poolside has no wiring paths"
  [ -z "$(fm_control_harness_turnend_token_path poolside /wt /st id1)" ] || fail "poolside has no turnend token path"
  pass "control tables: poolside exits and interrupts via Ctrl-C, empty wiring and turnend paths"
}

# --- 3. Session-lock identity + tmux liveness ----------------------------------

test_lock_identity_and_liveness() {
  fm_harness_process_matches pool '' || fail "session-lock identity must accept the exact pool name"
  fm_harness_process_matches /usr/local/bin/pool 'pool acp' || fail "session-lock identity must accept a pool path"
  ! fm_harness_process_matches spool '' || fail "session-lock identity must not accept spool"
  ! fm_harness_process_matches pull '' || fail "session-lock identity must not accept pull"
  # shellcheck source=bin/fm-backend.sh
  . "$ROOT/bin/fm-backend.sh"
  fm_backend_source tmux || fail "fm_backend_source tmux failed"
  [ "$(fm_backend_tmux_classify_process_name pool)" = agent ] || fail "tmux liveness must classify pool as an agent"
  [ "$(fm_backend_tmux_classify_process_name /opt/poolside/bin/pool)" = agent ] || fail "tmux liveness must classify a pool path as an agent"
  [ "$(fm_backend_tmux_classify_process_name spool)" != agent ] || fail "tmux liveness must not classify spool as an agent"
  [ "$(fm_backend_tmux_classify_process_name pull)" != agent ] || fail "tmux liveness must not classify pull as an agent"
  pass "session lock and tmux liveness: pool is anchored, decoys stay out"
}

# --- 4. Launch line -----------------------------------------------------------
# A fake pool binary (exit-0 stub) so resolve_pi_executable finds `pool` on the
# fake PATH; the launch itself is only recorded by FM_FAKE_LAUNCH_LOG.

make_spawn_case() {  # <name> <harness> <id>
  local name=$1 harness=$2 id=$3 case_dir home proj wt fakebin
  case_dir="$TMP_ROOT/$name"
  home="$case_dir/home"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  fakebin=$(make_spawn_fakebin "$case_dir/fake" pool)
  fm_test_spawn_home "$home" "$harness"
  fm_git_worktree "$proj" "$wt" "wt-$name"
  fm_test_spawn_brief "$home" "$id"
  : > "$case_dir/launch.log"
  printf '%s\n' "$case_dir|$home|$proj|$wt|$fakebin|$case_dir/launch.log"
}

read_case_record() {
  # shellcheck disable=SC2034 # CASE_DIR is part of the shared record shape
  IFS='|' read -r CASE_DIR HOME_DIR PROJ_DIR WT_DIR FAKEBIN_DIR LAUNCH_LOG <<EOF
$1
EOF
}

run_scout_spawn() {  # <home> <wt> <fakebin> <launch-log> <spawn-args...>
  local home=$1 wt=$2 fakebin=$3 launchlog=$4
  shift 4
  FM_FAKE_LAUNCH_LOG="$launchlog" fm_test_run_spawn "$home" "$wt" "$fakebin" "$@" --scout
}

test_spawn_launch_line_clears_markers_and_delivers_brief() {
  local rec id=poolside-launch out status launch state
  rec=$(make_spawn_case launch poolside "$id")
  read_case_record "$rec"
  out=$(run_scout_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$LAUNCH_LOG" "$id" "$PROJ_DIR" --harness poolside)
  status=$?
  expect_code 0 "$status" "poolside scout spawn should succeed: $out"
  assert_contains "$out" "spawned $id harness=poolside" "spawn did not report the poolside harness"
  state="$HOME_DIR/state"
  assert_grep "harness=poolside" "$state/$id.meta" "meta missing harness=poolside"
  launch=$(cat "$LAUNCH_LOG")
  assert_contains "$launch" "env -u CLAUDECODE -u PI_CODING_AGENT -u GROK_AGENT -u GEMINI_CLI -u CURSOR_AGENT -u CURSOR_INVOKED_AS FM_POOLSIDE_HARNESS=poolside" \
    "poolside launch did not clear foreign markers and establish its own"
  assert_contains "$launch" "FM_POOLSIDE_HARNESS=poolside '$FAKEBIN_DIR/pool' acp" "poolside launch did not invoke pool acp with its marker"
  assert_contains "$launch" "encode launch-brief" "poolside launch lost the canonical launch-brief envelope"
  assert_contains "$launch" "< '$HOME_DIR/data/$id/launch-brief.md'" "poolside launch lost the brief file path"
  case "$launch" in
    *"--model "*) fail "poolside launch must not pass --model (pool acp has no --model flag): $launch" ;;
  esac
  pass "fm-spawn: the poolside launch line clears markers, wires brief delivery, and omits --model"
}

# --- run all tests ---

test_detection_anchored_name_and_marker_precedence
test_control_tables
test_lock_identity_and_liveness
test_spawn_launch_line_clears_markers_and_delivers_brief
