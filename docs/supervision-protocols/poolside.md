Mode: poolside (Poolside pool CLI) via Herdr push-wake.

When this session owns supervision and away mode is not active:
1. Drain first with `bin/fm-wake-drain.sh`.
   After handling all emitted wakes and reconciling open decisions and unread status lines, run the exact `--ack-through` command printed as `WAKE_ACK_REQUIRED`; until then the work remains durable for idempotent re-handling after interruption.
2. The Herdr backend is push-capable: `bin/fm-watch.sh`'s `event_wait_or_sleep` replaces blind `sleep POLL` with a bounded native-event wait on Herdr's transition stream. A pane going `blocked` (e.g. the pool CLI hitting an approval gate or the ACP process exiting) wakes the supervisor sub-second instead of after the stale-pane wedge timer. The poll loop still runs every cycle as a fail-closed backstop, so push monitoring only ever shortens latency.
3. Busy state is sourced from Herdr native agent state (`herdr agent get <pane>`) supplemented by the shared composer verdict when native idle cannot close a turn (see `docs/verification/runtime-backends.md` "Native state").
4. Ordinary same-process session replacement (a new pool launch in the same Herdr pane) retires only the prior generation; when the replacement owns the fleet lock, its `session_start` arms the new generation without a model turn.
5. Ordinary signal, stale, check, heartbeat, or other wake handling: the Herdr push-wait already owns watcher continuity; do not arm another cycle yourself.
6. An unexpected pane close or Herdr socket disconnect enters bounded exponential retry inside the watcher; an exhausted retry or lost session lock is surfaced as a watcher failure instead of disappearing.
7. If a later notification explicitly reports a missing or failed cycle, drain queued wakes, inspect the failure text, and re-arm `bin/fm-watch-arm.sh`; do not use shell `&`.

Interrupt a poolside worker with Ctrl-C (via Herdr keys layer: `herdr pane send-keys <pane> ctrl+c`). Do not tear down the worktree or unland edits around a worker; use `bin/fm-control.sh` for lifecycle.

The Pi supervision branch (`docs/pi-supervision-branch.md`) is out of scope for the poolside primary: every actionable wake is delivered to this conversation, exactly as on omp.
