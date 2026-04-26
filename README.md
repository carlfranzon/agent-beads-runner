# abr — Agent Beads Runner

Portable parallel AI agent launcher using git worktrees + [beads](https://github.com/beads-dev/beads) issue tracking.

Run `abr` from any beads-enabled git repo to automatically pick a bead, create an isolated worktree, launch an AI coding agent, and clean up when done.

## Features

- **Multi-agent support** — Copilot CLI, Claude Code, Gemini CLI, Codex CLI
- **Parallel execution** — Run N agents simultaneously in tmux panes
- **Orchestrator dashboard** — Live colour-coded event feed in the center tmux pane
- **C&C prompt** — Interactive `abr>` command prompt to respawn, stop, or kill individual agent panes on the fly
- **Loop mode** — Keep picking beads until none remain
- **PR review** — Automated code review of agent-created PRs with agent-assisted conflict resolution
- **Model shortcuts** — Short names for all major models with effort/reasoning control
- **Graceful stop** — Ctrl+C, stop file, or SIGUSR1 to finish current bead and exit
- **Auto-cleanup** — Worktrees are created and destroyed automatically, and merged local agent branches are deleted

## Install

### Homebrew (recommended)

```bash
brew install carlfranzon/tap/abr
```

### Manual

```bash
git clone https://github.com/carlfranzon/agent-beads-runner.git
cd agent-beads-runner
make install
```

### Direct download

```bash
curl -fsSL https://raw.githubusercontent.com/carlfranzon/agent-beads-runner/main/bin/abr -o /usr/local/bin/abr
chmod +x /usr/local/bin/abr
```

## Prerequisites

- **git** — for worktree management
- **python3** — for JSON parsing
- **[bd (beads)](https://github.com/beads-dev/beads)** — issue tracker
- **At least one AI agent CLI:**
  - [Copilot CLI](https://docs.github.com/en/copilot) (default)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli)
  - [Codex CLI](https://github.com/openai/codex)
- **[gh](https://cli.github.com/)** — GitHub CLI (for PR creation/review)
- **[tmux](https://github.com/tmux/tmux)** — (for `--parallel` mode)
- **[gum](https://github.com/charmbracelet/gum)** — interactive C&C selectors and prompts

## Usage

```bash
# Launch orchestrator dashboard with 4 idle worker panes (default)
abr

# Work one bead then exit (skip orchestrator)
abr --no-tui

# Work a specific bead
abr --no-tui --bead yvs-49h.1.1

# Loop until no beads remain
abr --loop

# Loop through at most 5 beads
abr --loop-5

# 3 parallel agents in tmux panes
abr --parallel-3

# 3 tmux panes, each looping
abr --loop --parallel-3

# Launch orchestrator dashboard with 4 idle worker panes
abr --orchestrator

# Use Claude Code instead of Copilot
abr --agent claude

# Use Gemini CLI
abr --agent gemini

# Use Codex CLI
abr --agent codex

# Copilot with specific model and effort
abr --agent copilot --model opus46-h

# Review all open agent PRs
abr --review

# Review a specific PR
abr --review --pr 5

# Delete merged local agent/* branches
abr --prune-local-branches

# Delete merged remote agent/* branches (and stale remote refs)
abr --prune-remote-branches

# Preview what would happen
abr --dry-run

# Install abr skill for your AI agents
abr --install-skill

# Interactively configure default agent or model
abr --set-default-agent claude
abr --set-default-model sonnet46-h
```

## Options

| Option | Description |
|---|---|
| `--loop` | Keep respawning agents until no ready beads remain |
| `--loop-N` | Loop through at most N beads then stop |
| `--parallel-N` | Run N agents in tmux panes |
| `--parallel` | Shorthand for `--parallel-3` |
| `--no-tui` | Skip orchestrator TUI; run plain mode (one bead, or with `--loop`/`--parallel`) |
| `--orchestrator` | Launch orchestrator + C&C with 4 idle worker panes (explicit; same as default `abr`) |
| `--bead <id>` | Work on a specific bead |
| `--review` | Review open agent-created PRs |
| `--pr <number>` | With `--review`: review a specific PR |
| `--prune-local-branches` | Delete merged local `agent/*` branches |
| `--prune-remote-branches` | Delete merged remote `agent/*` branches and stale remote refs |
| `--agent <tool>` | AI tool: `copilot` (default), `claude`, `gemini`, `codex` |
| `--model <name>` | Model short name (see below) |
| `--new-tmux` | Create a separate tmux session |
| `--install-skill` | Install abr skill to AI agent platforms (interactive) |
| `--set-default-agent` | Configures your default agent interactively |
| `--set-default-model` | Configures your default model interactively |
| `--dry-run` | Show what would happen without executing |
| `--version`, `-V` | Show version |
| `-h`, `--help` | Show help |

## Model Shortcuts

Append effort suffixes: `-l` (low), `-m` (medium), `-h` (high), `-xh` (extra-high).

Example: `--model sonnet46-h` → Claude Sonnet 4.6 with high effort.

Run `abr --help` for the full model table per agent.

## Configuration

Run `abr --set-default-agent <tool>` or `abr --set-default-model <model>` to interactively save defaults to your workspace (`.abr.conf`) or globally (`~/.config/abr/config`).

Example `~/.config/abr/config` or `.abr.conf`:

```
agent = claude
model = sonnet46-h
```

Precedence: `--flag` > environment variable > workspace config > global config > built-in default.

| Key | Default | Purpose |
|-----|---------|---------|
| `agent` | `copilot` | Default agent backend |
| `model` | *(per-agent)* | Default model short name |
| `copilot_cli` | `copilot` | Path to Copilot CLI binary |
| `tmux_session` | `abr-<repo>` | tmux session name |

Override the config file location with `ABR_CONFIG` env var.

## Graceful Stop (loop mode)

- Press **Ctrl+C** once to finish the current bead and stop
- `touch .agent-stop` in the repo root (from another terminal)
- `kill -USR1 <pid>`
- From the C&C prompt: `stop --target A<n>` (per-agent graceful stop)

## Orchestrator Dashboard & C&C Prompt

When `--parallel-N` is used, a central orchestrator pane sits between the agent columns and shows a live colour-coded event feed. The bottom 4 lines of that pane are an interactive **Command & Control (C&C) prompt** (`abr> `).

Running `abr` (with no flags) launches the orchestrator by default. You can also use `--orchestrator` explicitly:

```bash
abr
# or explicitly:
abr --orchestrator
```

This launches the orchestrator and C&C plus 4 worker panes in idle state (no agents started yet). Pass `--no-tui` to skip orchestrator mode.

Pane aliases (`A1`, `A2`, …) are assigned in launch order and map to actual tmux pane IDs stored in `.abr-ipc/pane-A<n>`.

| Command | Effect |
|---|---|
| `run --target A1 [--agent X] [--model Y] [flags]` | Hot-swap: respawn agent in pane A1. Defaults to `--loop`; any extra abr flags are forwarded. |
| `stop --target A2` | Graceful stop: worker exits after finishing its current bead. |
| `kill --target A3` | Hard-kill: pane is replaced with a placeholder; window layout stays intact. |
| `status` | Writes a pane-alias → tmux-pane-ID liveness table to the dashboard. |
| `help` | Writes the command reference to the dashboard pane above. |
| `exit` / `quit` | Kill the whole tmux session (all panes) and return to terminal. |

Slash commands (new):

| Command | Effect |
|---|---|
| `/go` | Run a single agent on the next ready bead (uses defaults). |
| `/start` | Interactive launch flow (work target, agents, loops, agent, model, confirm). |
| `/agent` | Select and persist default agent to `.abr.conf`. |
| `/model` | Select and persist default model to `.abr.conf`. |
| `/beads` | Show kanban-style grouped bead board in dashboard. |
| `/bead` | Select a bead and choose `send to an agent`, `show info`, or `close`. |
| `/prune` | Interactively prune merged local, remote, or both branch sets. |
| `/review` | Run a single review agent on open agent PRs (uses current agent/model defaults). |
| `/help` | Show slash command reference in dashboard. |
| `/exit` / `/quit` | Kill the whole tmux session (all panes) and return to terminal. |

**Implementation notes:**
- `stop` writes `.abr-ipc/stop-A<n>` and sends `C-c`; `should_stop()` checks this file each loop iteration.
- `kill` uses `tmux respawn-pane -k` with a placeholder command so the visual grid never collapses.
- `run` uses `tmux respawn-pane -k` to hot-swap into the same pane slot.

## How It Works

1. Picks the next ready bead from the beads tracker
2. Claims it atomically (`bd update <id> --claim`)
3. Creates a fresh git worktree on a new branch
4. Copies env files and installs dependencies
5. Launches the AI agent with a structured prompt
6. Agent implements the bead, runs quality gates, commits, and pushes
7. Creates a PR via `gh`
8. Cleans up the worktree and local branch

## Branch Maintenance

- Run `abr --prune-local-branches` to clean up merged local `agent/*` branches from older PRs
- Run `abr --prune-remote-branches` to clean up merged remote `agent/*` branches and stale remote refs

## Quality Gate & Lint Policy

The review agent uses a **bead-scoped lint policy** to avoid blocking on pre-existing baseline lint debt:

**Worker agents:**
- Must fix any **new lint errors** in files they change
- Pre-existing baseline errors are acceptable (tracked separately)
- Report both baseline debt and new findings in commit notes

**Review agents:**
- ✅ **Approve** if: no new lint errors in changed files AND total lint count did not increase
- ❌ **Reject** if: new lint errors in changed files OR total lint count increased
- Non-blocking: Report pre-existing baseline debt as informational

**Benefits:**
- Unblocks single-bead work even if repo has baseline lint debt
- Prevents regressions (no new errors, no increased count)
- Separates lint hygiene (per-bead) from lint debt cleanup (separate epic)

For managing accumulated lint debt, create a dedicated lint-reduction bead/epic. When baseline reaches 0, restore full-repo lint as a hard gate.

## License

MIT
