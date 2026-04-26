---
name: abr
description: 'Launch parallel AI coding agents with abr (Agent Beads Runner). Use when: running agents on beads, launching parallel agents, starting agent loops, reviewing agent PRs, configuring agent models, using abr CLI, spawning tmux agent panes, managing worktrees for agents.'
argument-hint: 'Describe what you want to do, e.g. "launch 3 agents on ready beads" or "review open PRs with Gemini"'
---

# Agent Beads Runner (abr)

`abr` launches AI coding agents in isolated git worktrees to work on beads tasks. Each agent gets a fresh worktree, works one bead, creates a PR, and cleans up.

## Prerequisites

- `abr` installed (`brew tap carlfranzon/tap && brew install abr`)
- `bd` CLI installed and initialized in the repo (`bd init`)
- At least one agent CLI installed: `copilot`, `claude`, `gemini`, or `codex`
- `git`, `python3`, `gh` (GitHub CLI) available
- `tmux` required for `--parallel` mode
- `gum` for interactive C&C selectors and slash workflows

## Quick Reference

| Goal | Command |
|------|---------|
| Launch orchestrator (default) | `abr` |
| Work one bead, exit | `abr --no-tui` |
| Work a specific bead | `abr --no-tui --bead <id>` |
| Loop until no beads left | `abr --loop` |
| Loop through at most 5 beads | `abr --loop-5` |
| 3 parallel agents | `abr --parallel-3` |
| 3 parallel agents, each looping | `abr --loop --parallel-3` |
| Run one bead from C&C (slash) | `/go` |
| Interactive launch wizard (slash) | `/start` |
| Set default agent (slash) | `/agent` |
| Set default model (slash) | `/model` |
| Show bead board (slash) | `/beads` |
| Bead action menu (slash) | `/bead` |
| Prune merged branches (slash) | `/prune` |
| Review open agent PRs (slash) | `/review` |
| Slash help | `/help` |
| Shutdown orchestrator session (slash) | `/exit` or `/quit` |
| Respawn agent in pane A1 (C&C) | `run --target A1 [--model X]` |
| Graceful stop pane A2 (C&C) | `stop --target A2` |
| Hard-kill pane A3 (C&C) | `kill --target A3` |
| Show pane status (C&C) | `status` |
| Review all open agent PRs | `abr --review` |
| Review a specific PR | `abr --review --pr 5` |
| Review PRs in parallel | `abr --review --parallel-3` |
| Delete merged local branches | `abr --prune-local-branches` |
| Delete merged remote branches | `abr --prune-remote-branches` |
| Use a different agent | `abr --agent claude` |
| Use a specific model | `abr --agent copilot --model sonnet-46-h` |
| Preview without executing | `abr --dry-run` |
| Install skill for AI agents | `abr --install-skill` |
| Setup default agent | `abr --set-default-agent <tool>` |
| Setup default model | `abr --set-default-model <model>` |

## Agents

Four agent backends are supported via `--agent`:

| Agent | CLI | Default Model |
|-------|-----|---------------|
| `copilot` (default) | `copilot` | `claude-sonnet-4.6` (high effort) |
| `claude` | `claude` | `claude-sonnet-4-6` |
| `gemini` | `gemini` | `gemini-2.5-pro` |
| `codex` | `codex` | `gpt-5.4` |

## Model Selection

Use `--model <short-name>` with optional effort suffix.

### Short Names (most common)

| Short Name | Copilot Model | Claude Model |
|------------|---------------|--------------|
| `sonnet46` or `sonnet-46` | `claude-sonnet-4.6` | `claude-sonnet-4-6` |
| `sonnet45` or `sonnet-45` | `claude-sonnet-4.5` | `claude-sonnet-4-5` |
| `opus46` or `opus-46` | `claude-opus-4.6` | `claude-opus-4-6` |
| `opus45` or `opus-45` | `claude-opus-4.5` | `claude-opus-4-5` |
| `gpt54` or `gpt-54` | `gpt-5.4` | — |
| `gem25p` or `gem-25p` | `gemini-2.5-pro` | — |

### Effort Suffixes

Append `-l`, `-m`, `-h`, or `-xh` to any short name:

| Suffix | Meaning | Example |
|--------|---------|---------|
| `-l` | low | `sonnet46-l` |
| `-m` | medium | `gpt54-m` |
| `-h` | high | `sonnet-46-h` |
| `-xh` | extra-high | `gpt52-xh` |

Effort is passed via `--effort` for Copilot, `-c model_reasoning_effort` for Codex. Claude and Gemini parse but ignore effort (no CLI flag).

## Workflow of a Single Agent Run

1. `abr` picks the next ready bead (or uses `--bead <id>`)
2. Claims the bead (`bd update <id> --claim`) and pushes claim
3. Creates an isolated git worktree on a new branch (`agent/<bead-id>`)
4. Copies `.env*` files and installs dependencies
5. Launches the agent with a structured prompt
6. Agent implements changes, runs quality gates, commits, and pushes
7. `abr` creates a PR via `gh`
8. Worktree and local branch are cleaned up

## Branch Maintenance

- Delete merged local `agent/*` branches with `abr --prune-local-branches`
- Delete merged remote `agent/*` branches (and stale remote refs) with `abr --prune-remote-branches`

## Graceful Stop (Loop Mode)

- Press `Ctrl+C` once to finish the current bead and stop
- From another terminal: `touch <repo-root>/.agent-stop`
- Send signal: `kill -USR1 <pid>`
- From the C&C prompt: `stop --target A<n>` (per-agent graceful stop)

## Tmux Session Management

- Sessions are named `abr-<repo-name>` by default
- New `--parallel` panes are added to existing sessions
- Use `--new-tmux` to create a separate session
- Override name with `TMUX_SESSION=<name>` env var

## Orchestrator Dashboard & C&C Prompt (Parallel Mode)

When `--parallel-N` is used a central orchestrator pane shows a live colour-coded event feed. The bottom 4 lines of that pane are an interactive **C&C prompt** (`abr> `).

Pane aliases `A1`, `A2`, … are assigned in launch order. The alias→tmux-pane-ID map is stored in `.abr-ipc/pane-A<n>` by each worker.

| Command | Effect |
|---|---|
| `run --target A1 [--agent X] [--model Y] [flags]` | Hot-swap: respawn agent via `tmux respawn-pane -k`. Defaults to `--loop`. |
| `stop --target A2` | Graceful stop: worker exits after finishing current bead. |
| `kill --target A3` | Hard-kill: pane replaced with placeholder; layout intact. |
| `status` | Pane-alias → ID liveness table written to dashboard. |
| `help` | Command reference written to dashboard. |
| `exit` / `quit` | Close the C&C prompt. |

## Config Files

Users can set defaults interactively via `abr --set-default-agent <tool>` and `abr --set-default-model <model>`. You can save these to your workspace (`.abr.conf`) or globally (`~/.config/abr/config`). Override global location with `ABR_CONFIG` env var.

```
agent = claude
model = sonnet46-h
```

Precedence: `--flag` > env var > workspace config > global config > built-in default.

| Key | Default | Purpose |
|-----|---------|---------|
| `agent` | `copilot` | Default agent backend |
| `model` | *(per-agent)* | Default model short name |
| `copilot_cli` | `copilot` | Path to Copilot CLI binary |
| `tmux_session` | `abr-<repo>` | tmux session name |

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `AGENT_TOOL` | `copilot` | Default agent backend (overrides config file) |
| `COPILOT_CLI` | `copilot` | Path to Copilot CLI binary |
| `TMUX_SESSION` | `abr-<repo>` | tmux session name |
| `ABR_CONFIG` | `~/.config/abr/config` | Path to config file |

## Procedure

When the user wants to launch agents:

1. Verify prerequisites: `command -v abr bd git gh tmux`
2. Ensure beads are initialized: `bd ready` should list beads
3. Construct the `abr` command from the quick reference table above
4. If unsure, use `--dry-run` first to preview
5. Run the command
6. For parallel mode, attach to tmux: `tmux attach -t abr-<repo-name>`
7. Monitor progress in tmux panes; agents auto-clean up when done
