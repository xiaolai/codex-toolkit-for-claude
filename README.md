# codex-toolkit

OpenAI Codex MCP integration for Claude Code.

Use OpenAI's Codex models as an autonomous worker from within Claude Code — for code audits, implementation, verification, bug analysis, and plan review.

## Installation

### Prerequisites

1. Install [Codex CLI](https://github.com/openai/codex) (v0.101.0 or later):

```bash
npm install -g @openai/codex
```

2. Authenticate with OpenAI — we recommend using a subscription (ChatGPT Plus/Pro) rather than an API key:

```bash
codex login
```

If you prefer using an API key instead, set it in your environment:

```bash
export OPENAI_API_KEY="your-key-here"
```

### Install the plugin

First, add the marketplace (once):

```
/plugin marketplace add xiaolai/claude-plugin-marketplace
```

Then install:

```
/plugin install codex-toolkit@xiaolai
```

Choose an install scope based on your needs:

| Scope | Command | Effect |
|-------|---------|--------|
| **User** (default) | `/plugin install codex-toolkit@xiaolai` | Available in all your projects |
| **Project** | `/plugin install codex-toolkit@xiaolai --scope project` | Shared with team via `.claude/settings.json` (committed to repo) |
| **Local** | `/plugin install codex-toolkit@xiaolai --scope local` | Only you, only this repo (gitignored) |

### Configure for your project (optional)

Run `/init` inside your project to generate a `.codex-toolkit.md` config file. This lets you set project-specific defaults:

- Default model and reasoning effort
- Audit focus (balanced, security-first, performance-first, quality-first)
- File patterns to skip during audits
- Project-specific instructions for Codex (your stack, conventions, constraints)

If no config file exists, commands use sensible built-in defaults.

## Commands

| Command | Description |
|---------|-------------|
| `/init` | Initialize project config — set default model, audit focus, skip patterns |
| `/preflight` | Check Codex connectivity, auth status, and discover available models |
| `/implement` | Delegate an implementation plan to Codex for autonomous execution |
| `/audit` | Code audit — fast 5-dimension (`--mini`, default) or thorough 9-dimension (`--full`) |
| `/verify` | Verify that issues from a previous audit have been fixed |
| `/bug-analyze` | Root cause analysis for user-described bugs |
| `/review-plan` | Architectural review of implementation plans |
| `/audit-fix` | Full audit→fix→verify loop — runs until all issues are resolved or you stop |
| `/continue` | Continue a previous Codex session — iterate on findings or request fixes |

> When installed as a plugin, commands appear as `/codex-toolkit:<command>` (e.g. `/codex-toolkit:audit`).

## How it works

Each command follows the same pattern:

1. **Choose model and settings** — pick a Codex model, reasoning effort, and sandbox level
2. **Send to Codex** — the task is dispatched to `mcp__codex__codex` (Codex running as an MCP server) with `developer-instructions` to set the role persona and `config` for reasoning effort
3. **Fallback** — if Codex is unavailable or returns empty, Claude performs the task manually
4. **Report** — structured output with findings, verdicts, thread ID, and next steps

Every command output includes a **thread ID** that you can pass to `/continue` to iterate on findings, request fixes, or drill deeper — without re-sending the full context.

## Audit→Fix→Verify workflow

The `/audit-fix` command runs the full cycle automatically:

```
audit → fix → verify → (issues remain?) → fix → verify → ... → ACCEPTED
```

1. Audits your code (mini or full — your choice)
2. Sends findings to Claude or Codex to fix (your choice)
3. Verifies each fix was actually resolved
4. Repeats up to 3 rounds or until clean
5. Reports final status: ACCEPTED / PARTIAL / UNCHANGED

You can also run each step manually:

```
/audit               # find issues (defaults to --mini)
/audit --full        # thorough 9-dimension audit
# fix them yourself
/verify report.md    # check your fixes
```

## Available models

Models are discovered dynamically at runtime. Each command runs `scripts/codex-preflight.sh`, which probes a list of candidate models in parallel. Invalid models fail fast; valid ones are kept. When multiple versions of the same model family are available (e.g. `gpt-5.3-codex` and `gpt-5.2-codex`), only the newest is shown.

The candidate list lives in `scripts/codex-preflight.sh` — add new model names there as OpenAI releases them. Stale entries are harmless; they simply probe as unavailable.

To check availability manually:

```bash
bash scripts/codex-preflight.sh    # JSON to stdout
```

Or run `/preflight` inside Claude Code for a human-friendly report.

## MCP server

This plugin bundles a `.mcp.json` that registers the Codex MCP server. Codex authenticates via subscription (recommended, use `codex login`) or an `OPENAI_API_KEY` environment variable.

If you already have Codex configured in your `~/.claude/config.json`, the plugin's MCP config will coexist — but you may want to remove the duplicate from `config.json` to avoid running two Codex MCP servers.
