# poolside (Poolside pool CLI)

Verified for primary harness use on Herdr.
poolside is the Poolside `pool` CLI (v1.0.16+), an ACP (Agent Client Protocol) client that
runs on the Herdr backend. It publishes no harness-identity env marker of its own; detection
is anchored on the process name `pool` in the ancestry walk.

Cross-harness provider and credential identity is owned by `references/common/model-and-effort.md`.

## Operating facts

| Fact | Value |
|---|---|
| Binary | `pool`, resolved from `PATH` by `../../../bin/fm-spawn.sh`; a missing binary refuses the spawn. |
| Launch | `pool acp` inside a Herdr pane (ACP server mode); the pool CLI reads `~/.config/poolside/settings.yaml` for agent_mode, mode, model, and thought_level. |
| Busy state | `../../../bin/fm-busy-lib.sh` source `herdr`: uses Herdr native agent state (`herdr agent get <pane>`) plus the shared composer verdict when native idle cannot close a turn. |
| Exit command | Ctrl-C (Herdr keys layer: `herdr pane send-keys <pane> ctrl+c`). No verified textual `/exit` slash command yet — use Ctrl-C. |
| Interrupt | Single Ctrl-C; the composer is left empty. |
| Skill invocation | `pool` does not expose a verified separate skill form; use natural language when the exact command is uncertain. |
| Model flag | `-m, --model <model>`; accepts provider/model form or model name. Default model from settings.yaml: `poolside/laguna-s-2.1`. |
| Effort flag | Not supported by the pool CLI. `effort=` may be recorded in task metadata but no flag is emitted. |
| Model discovery | `pool` does not ship a model-listing subcommand verified by Firstmate; models are configured in `settings.yaml` under `agent_servers.<name>.default_config_options.model` and overridden per-launch with `--model`. |
| Marker | None of poolside's own. `HERDR_ENV=1` and the `HERDR_*` vars come from the Herdr backend, not from pool, so they are backend evidence, not harness identity. Detection is by anchored process name `pool` in the ancestry (see Detection below). |
| Composer | No poolside-specific composer shape is verified; busy text relies on Herdr native agent state plus the shared composer classifier. |
| Autonomy | `mode: always-allow` in settings.yaml auto-approves all tool calls; there is no project-trust gate and no approval prompt. |
| Trust | No trust dialog: the `always-allow` mode suppresses approval gates. |
| Resume | `-r, --resume <session-id>` exists; use deterministic relaunch through `bin/fm-control.sh relaunch` rather than relying on native resume for Firstmate supervision. |
| Worktree support | `-w, --worktree <branch>` creates and checks out a git worktree for the named branch; the spawn owner `../../../bin/fm-spawn.sh` uses its own Treehouse worktree lease instead. |

## Detection

`../../../bin/fm-harness.sh` walks the process ancestry and matches the exact comm name
`pool`. Because `pool` is a short, generic word, the match is deliberately anchored
(`pool)` in the case statement, never `*pool*`), so unrelated commands such as `pull`,
`spool`, or `poold` cannot be misread as this harness.

poolside publishes no harness-identity env marker; `HERDR_ENV=1` is a backend marker set by
Herdr, not by pool. Detection therefore relies solely on the anchored ancestry comm match.

`../../../bin/fm-session-lock-lib.sh` and `../../../bin/fm-backend.sh` classify the Herdr
backend for liveness; poolside inherits Herdr's push-event and native-agent-state support
from the verified `herdr.sh` backend adapter.

## Primary integration

poolside runs on the Herdr backend, so its supervision wake mechanism is Herdr native push
events and per-pane agent state. The turn-end guard and watcher arm contract follow the
generic Herdr supervision protocol documented in `../../../docs/supervision-protocols/poolside.md`.
The Pi supervision branch (`docs/pi-supervision-branch.md`) is out of scope for the poolside
primary: every actionable wake is delivered to this conversation.

`bin/fm-session-start.sh` prints `POOLSIDE_WATCH: loaded` when the running poolside session
has the required Herdr socket identity; it warns when the socket is absent or the pane
identity cannot be resolved.
