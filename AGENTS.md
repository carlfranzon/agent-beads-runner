# Agent Beads Runner (abr)

## What This Is

`abr` is a bash CLI that launches AI coding agents in isolated git worktrees to work on beads (task tickets stored in an embedded Dolt database via the `bd` CLI). It supports Copilot, Claude, Gemini, and Codex as agent backends, with parallel execution via tmux.

## Repository Structure

- `bin/abr` — The entire tool. Single bash script, no build step.
- `Formula/abr.rb` — Homebrew formula (lives in the `carlfranzon/homebrew-tap` repo, mirrored here for reference).
- `.github/workflows/release.yml` — CI: auto-tags on version bump, creates GitHub Release, updates Homebrew tap.
- `.github/skills/abr/SKILL.md` — Canonical skill file (symlinked from `.agents/` and `.claude/`, embedded in `--install-skill`).

## Build & Test

No build step. The script is self-contained bash.

To test locally after changes:
```bash
# Run directly
./bin/abr --help
./bin/abr --version

# Test model resolution (source the function, then call it)
bash -c '
eval "$(sed -n "/<line of resolve_model_and_effort>/,/^}/p" bin/abr)"
resolve_model_and_effort copilot sonnet-46-h
echo "$MODEL_RESOLVED $EFFORT_RESOLVED"
'
```

## Conventions

- **Single-file architecture**: Everything lives in `bin/abr`. Do not split into multiple files.
- **Version**: `ABR_VERSION` variable near top of `bin/abr`. Bump it for every release. A pre-commit hook (`.githooks/pre-commit`) auto-bumps the patch component if you forget; activate it with `make install-hooks`.
- **Config file**: User defaults live in `~/.config/abr/config` (global) or `.abr.conf` (workspace) (simple `key = value` format). Parsed with a while-read loop in the Configuration section. Precedence: `--flag` > env var > workspace config > global config > built-in default.
- **Model short names**: The `resolve_model_and_effort()` function maps short names to full model identifiers. Always support both compact (`sonnet46`) and dashed (`sonnet-46`) forms. Update the help text table when adding models.
- **Agent backends**: Each agent (copilot, claude, gemini, codex) has its own case block in `resolve_model_and_effort()` AND in the agent launch sections (`run_one_bead`, `review_one_pr`, conflict resolution). Changes to one must be mirrored to the others.
- **Linting policy**: Worker agents must fix new lint errors in changed files but may leave pre-existing baseline errors. Review agents approve if no new lint errors in changed files and total count did not increase. This unblocks bead-scoped work while preventing regressions. See `build_agent_prompt()` and `build_review_prompt()` for the lint logic.
- **Locking**: All `bd` commands that may write go through `bd_locked()` (mkdir-based mutex). Never call `bd` directly for write operations.
- **Branch hygiene**: Successful review merges should remove remote and local `agent/*` branches. Use `abr --prune-local-branches` for local cleanup and `abr --prune-remote-branches` for merged remote cleanup.
- **Orchestrator & C&C panes**: The orchestrator (`--internal-orchestrator N`) splits itself on startup (4 lines at the bottom) to spawn the C&C prompt (`--internal-cc N`). Both are internal modes dispatched early in `main()` before any `bd`/git checks. `run_orchestrator`, `run_cc`, and the `cc_cmd_*` helpers all live directly in `bin/abr`.
- **User-facing orchestrator mode**: Running `abr` (default) or `abr --orchestrator` (explicit) must launch a dedicated orchestrator workspace with C&C plus 4 idle worker panes (registered as A1..A4), without auto-starting agents. Use `--no-tui` to skip orchestrator mode and run a plain single-bead session instead.
- **C&C command style**: Slash commands are first-class (`/go`, `/start`, `/agent`, `/model`, `/beads`, `/bead`, `/prune`, `/review`, `/update`, `/help`, `/exit`, `/quit`), with legacy `run/stop/kill/status/help/exit/quit` retained for compatibility. When adding C&C commands, update `run_cc` dispatch, add a `cc_cmd_*` helper, update `cc_cmd_help`, and document in README/SKILL.
- **Pane registration**: Every worker pane writes `$TMUX_PANE` to `.abr-ipc/pane-A<n>` as its first act. This alias→ID file is what `cc_resolve_target()` reads. All three `pane_cmds` build sites (loop-mode, non-loop, review) must keep the registration `printf` line.
- **Commit messages**: Use conventional commits — `fix:`, `feat:`, `ci:`, `docs:`.
- **Documentation sync**: When adding or changing features, always update ALL of these in the same commit: `--help` text in `bin/abr`, `README.md`, `AGENTS.md`, and `.github/skills/abr/SKILL.md` (which is the canonical source for the embedded SKILL in `--install-skill` and the symlinked copies in `.agents/` and `.claude/`).

## Release Process

1. Bump `ABR_VERSION` in `bin/abr`
2. Commit and push to `main`
3. The `release.yml` workflow auto-tags, creates a GitHub Release, and updates the Homebrew tap

## Things to Watch Out For

- **Effort suffix parsing**: The `-l`, `-m`, `-h`, `-xh` suffixes are stripped from model short names before lookup. Short names must NOT end with these suffixes unless they represent effort levels. For example, `gpt54m` means "gpt-5.4-mini" (not effort=medium) — the `m` is part of the short name, not a suffix, because it's not preceded by `-`.
- **`grep -oP`**: Used in CI workflows. macOS `grep` doesn't support `-P` (Perl regex), but GitHub Actions runners use GNU grep. Don't use `-P` in the main script itself.
- **Parallel safety**: Multiple agents may run simultaneously. Any shared state (beads DB, git operations) must go through `bd_locked()` or handle contention gracefully.
- **C&C pane height**: The C&C prompt is only 4 lines tall. Commands that produce multi-line output (like `help` and `status`) must append to the event log file (`.abr-ipc/events.log`) so the output appears in the large orchestrator dashboard above, not in the cramped C&C pane.
- **`respawn-pane` for kill/run**: Never use `tmux kill-pane` for agent panes — it collapses the column layout. Always use `tmux respawn-pane -k -t <pane-id> "<cmd>"` to replace pane content while keeping the grid intact.
- **`pick_next_bead()` skips worktrees**: In addition to filtering IPC-claimed bead IDs, `pick_next_bead()` also scans `${WORKTREE_BASE}/agent/` and skips any bead whose worktree directory already exists. This prevents the spin-loop where a loop agent repeatedly picks a bead, finds the worktree (another agent is working on it), skips it, then picks it again — because `ipc_clear_claim()` is called after each child exits (even on failure), so the IPC claim alone is not enough once the child finishes.
- **Blocked beads on the board**: `_run_beads_board()` fetches a BLOCKED section via `bd list --status blocked --json` (mapped through `_bd_args_for_status`). `pick_next_bead()` is already blocker-aware via `bd ready`; the board section is purely for visibility. Do not touch `pick_next_bead()` when making board changes.
- **PR rejection — attempt counter**: When `review_one_pr()` rejects a PR, the child bead title includes `[attempt N]`. `N` is derived from the parent bead's title: if it contains `[attempt K]` the child gets `[attempt K+1]`; otherwise N=2. This applies to both the `reject)` and `*)` (unknown verdict) cases.
- **PR rejection — branch cleanup**: The `reject)` and `*)` cases in `review_one_pr()` now delete the remote `agent/*` branch with `git push origin --delete "$branch"` after closing the PR, matching the approve path.
- **JSONL trace log**: `ipc_event()` writes a parallel JSONL record to `${ABR_LOG_DIR}/session.jsonl` for every event. The pipe-delimited `events.log` format is unchanged. The 3rd argument to `ipc_event()` is the optional `bead_id` field. Call sites inside `run_one_bead()` and `review_one_pr()` pass it; EXIT/INFO/summary calls leave it absent (defaults to `""`). ABR_LOG_DIR is set in `launch_tmux()` for TUI runs and in `main()` (just before loop/single-bead dispatch) for `--no-tui` runs.
- **Per-project prompt customization**: `build_agent_prompt()` and `build_review_prompt()` both read `~/.config/abr/prompt.md` (global) and `${REPO_ROOT}/.abr/prompt.md` (workspace) and append both under a `## Project-Specific Instructions` / `## Project-Specific Review Instructions` heading. `ABR_PROMPT_FILE` env var or `prompt_file` config key overrides the workspace path. When neither file exists the prompts are byte-for-byte identical to before this feature.
- **Plan mode**: `abr --plan` is a human-in-the-loop feature decomposition wizard. It uses interactive (not autopilot) agent sessions. The planning agent runs in the repo root (not a worktree). OpenSpec integration is optional — detected at runtime, offered for install if missing. Plan artifacts are stored in `.abr/plans/<feature>/`. When OpenSpec is enabled, `tasks.md` is a write-once snapshot (not maintained); bead status is the source of truth.
