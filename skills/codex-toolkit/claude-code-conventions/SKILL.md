---
name: claude-code-conventions
description: "Canonical reference for Claude Code plugin artifact schemas, hook events, frontmatter fields, and naming conventions. Used to inject domain knowledge into Codex audit prompts. Run /codex-toolkit:refresh-knowledge to update from latest docs."
version: 0.1.0
---

# Claude Code Plugin Conventions Reference

> **Purpose**: This skill is the single source of truth for Claude Code artifact conventions. Audit commands inject this content into Codex's `developer-instructions` so Codex can accurately validate Claude Code artifacts despite having no native knowledge of the platform.
>
> **Freshness**: Last updated 2026-03-25. Run `/codex-toolkit:refresh-knowledge` to refresh from official docs.

## plugin.json Schema

Required fields:
- `name` (string): plugin identifier, kebab-case
- `version` (string): semver format `X.Y.Z`
- `description` (string): one-line purpose

Optional fields:
- `author` (object): `{ "name": "string", "email": "string" }`
- `license` (string): SPDX identifier
- `keywords` (string[]): discovery tags
- `commands` (object): explicit command registration (auto-discovered if omitted)
- `agents` (object): explicit agent registration (auto-discovered if omitted)
- `skills` (object): explicit skill registration (auto-discovered if omitted)
- `hooks` (object): hook configuration
- `mcpServers` (object): MCP server registration
- `lspServers` (object): LSP server registration
- `outputStyles` (object): custom output formatting

## Command Frontmatter

Location: `commands/<name>.md` (auto-discovered)

Required fields:
- `description` (string): shown in `/help`, must be specific and actionable

Optional fields:
- `argument-hint` (string): usage pattern shown to user (e.g., `"<file> [--flag]"`)
- `allowed-tools` (string[]): restrict available tools. If omitted, all tools available
- `model` (string): override session model (`haiku`, `sonnet`, `opus`)
- `user-invocable` (boolean): set to `false` for shared partials in `commands/shared/`

Body: imperative instructions FOR Claude, not documentation TO user.

## Shared Partial Frontmatter

Location: `commands/shared/<name>.md`

Required:
- `user-invocable: false`

These are referenced by commands to eliminate boilerplate. Not shown in `/help`.

## Agent Frontmatter

Location: `agents/<name>.md` (auto-discovered)

Required fields:
- `description` (string): MUST include `<example>` blocks showing when to trigger

Recommended fields:
- `model` (string): `haiku`, `sonnet`, `opus`
- `color` (string): `cyan`, `blue`, `magenta`, `yellow`, `green`, `red`
- `tools` (string[] or comma-separated string): tools available to the agent
- `skills` (string[]): skills loaded into agent context, format `plugin-name:skill-name`

Body: system prompt defining the agent's mission, instructions, and output format.

## Skill Structure

Location: `skills/<plugin-name>/<skill-name>/SKILL.md`

Required frontmatter:
- `name` (string): skill identifier
- `description` (string): when/why to use this skill — acts as trigger for auto-loading

Optional frontmatter:
- `version` (string): semver
- `globs` (string or string[]): file patterns that scope this skill

Body: reference material in imperative form. Keep under 500 lines for context efficiency.

Supporting files: `references/`, `examples/`, `scripts/` subdirectories (optional).

## Hook Events

Location: `hooks/hooks.json` or inline in agent frontmatter

Valid event types:
- `PreToolUse` — before a tool executes (can block)
- `PostToolUse` — after a tool executes
- `PostToolUseFailure` — after a tool fails
- `PermissionRequest` — when permission is needed
- `UserPromptSubmit` — when user sends a message
- `Stop` — when Claude stops responding
- `SubagentStop` — when a subagent completes
- `SessionStart` — when a session begins
- `SessionEnd` — when a session ends
- `PreCompact` — before context compression
- `Notification` — for notifications
- `InstructionsLoaded` — after CLAUDE.md files are loaded

Hook types:
- `command` — run a shell command, receives JSON on stdin
- `prompt` — inject a prompt into Claude's context
- `agent` — spawn a verification agent

Hook output (for `command` type):
```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow" | "deny",
    "permissionDecisionReason": "explanation"
  }
}
```

Matcher: regex pattern for tool name (e.g., `"Bash"`, `"mcp__.*"`)

## hooks.json Format

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node ${CLAUDE_PLUGIN_ROOT}/scripts/guard.js"
          }
        ]
      }
    ]
  }
}
```

## .mcp.json Format

```json
{
  "mcpServers": {
    "server-name": {
      "command": "executable",
      "args": ["arg1", "arg2"],
      "cwd": "${CLAUDE_PLUGIN_ROOT}",
      "env": { "KEY": "value" }
    }
  }
}
```

## marketplace.json Format

Per-plugin marketplace (for `claude plugin marketplace add`):

```json
{
  "name": "marketplace-name",
  "owner": { "name": "author-name" },
  "plugins": [
    {
      "name": "plugin-name",
      "source": { "source": "github", "repo": "owner/repo" },
      "description": "...",
      "version": "X.Y.Z",
      "author": { "name": "..." },
      "category": "developer-tools"
    }
  ]
}
```

Source types: `github`, `git`, `url`, `npm`, `file`, `directory`, `hostPattern`

## Plugin Directory Layout

```
plugin-name/
├── .claude-plugin/
│   ├── plugin.json           # required
│   └── marketplace.json      # optional
├── commands/                  # auto-discovered
│   ├── command-name.md
│   └── shared/               # non-invocable partials
│       └── partial-name.md
├── agents/                    # auto-discovered
│   └── agent-name.md
├── skills/                    # auto-discovered
│   └── plugin-name/
│       └── skill-name/
│           └── SKILL.md
├── hooks/
│   └── hooks.json
├── scripts/                   # utility scripts
├── .mcp.json                  # optional MCP servers
├── CLAUDE.md                  # project instructions
├── README.md
└── LICENSE
```

`${CLAUDE_PLUGIN_ROOT}` resolves to the plugin's root directory at runtime.

## Naming Conventions

- Plugin names: kebab-case (`reading-assistant`, `codex-toolkit`)
- Command files: kebab-case `.md` (`audit-plugin.md`)
- Agent files: kebab-case `.md` (`qc-coordinator.md`)
- Skill directories: `plugin-name/skill-name/`
- Script files: kebab-case with extension (`codex-preflight.sh`, `parse_epub.py`)

## Settings Files

- `~/.claude/settings.json` — global user settings
- `{project}/.claude/settings.json` — project settings (committed)
- `{project}/.claude/settings.local.json` — local settings (gitignored)
- `.claude/<plugin-name>.local.md` — per-plugin config with YAML frontmatter

## CLAUDE.md

- Project-level instructions for Claude Code
- Supports `@` import syntax to reference other files
- Loaded from: project root, `.claude/`, `~/.claude/`, parent directories
- Priority: closer to project root wins

## Quality Standards for Artifacts

### Commands
- Description must be specific and actionable (not "does stuff")
- Steps must be numbered and unambiguous
- Tool requirements must match `allowed-tools`
- Output format must be defined
- Error paths must be specified

### Agents
- Description MUST include `<example>` blocks
- Model should match task complexity (haiku for mechanical, sonnet for reasoning, opus for judgment)
- Tools should follow least-privilege
- System prompt should define mission, instructions, and output format

### Skills
- Description acts as trigger — must contain specific phrases that match user queries
- Body should be under 500 lines
- Content should teach patterns, not theory
- Code examples should be runnable, not pseudocode

### Rules (.claude/rules/)
- YAML frontmatter with `description` (required) and `paths` (optional)
- Total budget: <500 lines across all rule files
- Each rule: bold imperative + rationale + positive framing
- Must be enforceable (testable, specific, observable)
- Must not duplicate linter/formatter/CI enforcement
