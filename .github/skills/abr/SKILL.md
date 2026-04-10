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

## Quick Reference

| Goal | Command |
|------|---------|
| Work one bead, exit | `abr` |
| Work a specific bead | `abr --bead <id>` |
| Loop until no beads left | `abr --loop` |
| Loop through at most 5 beads | `abr --loop-5` |
| 3 parallel agents | `abr --parallel-3` |
| 3 parallel agents, each looping | `abr --loop --parallel-3` |
| Review all open agent PRs | `abr --review` |
| Review a specific PR | `abr --review --pr 5` |
| Review PRs in parallel | `abr --review --parallel-3` |
| Use a different agent | `abr --agent claude` |
| Use a specific model | `abr --agent copilot --model sonnet-46-h` |
| Preview without executing | `abr --dry-run` |
| Install skill for AI agents | `abr --install-skill` |

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
8. Worktree is cleaned up

## Graceful Stop (Loop Mode)

- Press `Ctrl+C` once to finish the current bead and stop
- From another terminal: `touch <repo-root>/.agent-stop`
- Send signal: `kill -USR1 <pid>`

## Tmux Session Management

- Sessions are named `abr-<repo-name>` by default
- New `--parallel` panes are added to existing sessions
- Use `--new-tmux` to create a separate session
- Override name with `TMUX_SESSION=<name>` env var

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `AGENT_TOOL` | `copilot` | Default agent backend |
| `COPILOT_CLI` | `copilot` | Path to Copilot CLI binary |
| `TMUX_SESSION` | `abr-<repo>` | tmux session name |

## Procedure

When the user wants to launch agents:

1. Verify prerequisites: `command -v abr bd git gh tmux`
2. Ensure beads are initialized: `bd ready` should list beads
3. Construct the `abr` command from the quick reference table above
4. If unsure, use `--dry-run` first to preview
5. Run the command
6. For parallel mode, attach to tmux: `tmux attach -t abr-<repo-name>`
7. Monitor progress in tmux panes; agents auto-clean up when done
