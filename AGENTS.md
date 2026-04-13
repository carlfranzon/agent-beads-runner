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
- **Version**: `ABR_VERSION` variable near top of `bin/abr`. Bump it for every release.
- **Config file**: User defaults live in `~/.config/abr/config` (global) or `.abr.conf` (workspace) (simple `key = value` format). Parsed with a while-read loop in the Configuration section. Precedence: `--flag` > env var > workspace config > global config > built-in default.
- **Model short names**: The `resolve_model_and_effort()` function maps short names to full model identifiers. Always support both compact (`sonnet46`) and dashed (`sonnet-46`) forms. Update the help text table when adding models.
- **Agent backends**: Each agent (copilot, claude, gemini, codex) has its own case block in `resolve_model_and_effort()` AND in the agent launch sections (`run_one_bead`, `review_one_pr`, conflict resolution). Changes to one must be mirrored to the others.
- **Linting policy**: Worker agents must fix new lint errors in changed files but may leave pre-existing baseline errors. Review agents approve if no new lint errors in changed files and total count did not increase. This unblocks bead-scoped work while preventing regressions. See `build_agent_prompt()` and `build_review_prompt()` for the lint logic.
- **Locking**: All `bd` commands that may write go through `bd_locked()` (mkdir-based mutex). Never call `bd` directly for write operations.
- **Branch hygiene**: Successful review merges should remove remote and local `agent/*` branches. Use `abr --prune-local-branches` for local cleanup and `abr --prune-remote-branches` for merged remote cleanup.
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
