# codex-toolkit-for-claude

OpenAI Codex MCP integration for Claude Code. Slash commands that delegate work to Codex running as an MCP server.

## Project structure

```
commands/           Slash command definitions (*.md with YAML frontmatter)
  _model-selection.md   Shared partial — dynamic model discovery (not a standalone command)
  codex-preflight.md    /codex-preflight — connectivity + model check
  codex-implement.md    /codex-implement — autonomous plan execution
  codex-audit.md        /codex-audit — full 9-dimension code audit
  codex-audit-mini.md   /codex-audit-mini — fast 5-dimension audit
  codex-verify.md       /codex-verify — verify fixes from previous audit
  codex-bug-analyze.md  /codex-bug-analyze — root cause analysis
  codex-review-plan.md  /codex-review-plan — architectural plan review
  codex-audit-fix.md    /codex-audit-fix — audit→fix→verify loop
  codex-continue.md     /codex-continue — multi-turn follow-up via codex-reply
  codex-init.md         /codex-init — generate .codex-toolkit-for-claude.md project config
scripts/
  codex-preflight.sh    Model discovery script (probes candidates in parallel)
.mcp.json               Registers Codex MCP server
.claude-plugin/
  plugin.json           Plugin metadata
```

## Conventions

### MCP tool calls

- `model_reasoning_effort` MUST go inside the `config` object, not as a top-level parameter:
  ```
  config: {"model_reasoning_effort": "{chosen_effort}"}
  ```
- Every command that calls `mcp__codex__codex` MUST include `developer-instructions` with a role-specific persona.
- Every command report MUST include the `threadId` from the Codex response so users can follow up with `/codex-continue`.

### Project config (`.codex-toolkit-for-claude.md`)

Users can run `/codex-init` to generate a `.codex-toolkit-for-claude.md` in their project root. This file is optional — all commands work without it.

When present, `_model-selection.md` reads it at Step 0 and uses its values as defaults. Priority: user choice > project config > command defaults.

Config fields:
- **Default model/effort/sandbox** — override recommended values
- **Default audit type** — mini or full
- **Audit focus** — balanced, security-first, performance-first, quality-first
- **Skip patterns** — glob patterns to exclude from audits
- **Project-specific instructions** — appended to developer-instructions for all commands

### Command structure

All commands follow this pattern:
1. Load `.codex-toolkit-for-claude.md` project config if it exists (Step 0)
2. Run `scripts/codex-preflight.sh` via `commands/_model-selection.md` to discover models
3. Present choices via `AskUserQuestion` (model, effort, optionally sandbox)
4. Ping Codex with a short availability test
5. Send the real task to Codex via `mcp__codex__codex`
6. If Codex fails or returns empty, fall back to manual analysis
7. Display structured report with threadId

### Model selection

- Models are discovered dynamically — never hardcode model availability
- The `_model-selection.md` partial handles all model/effort/sandbox selection
- Each command specifies its recommended model, effort, and whether sandbox is relevant

### Adding new commands

1. Create `commands/codex-<name>.md` with YAML frontmatter (`description`, optional `argument-hint`)
2. Reference `commands/_model-selection.md` for model selection
3. Use `config: {"model_reasoning_effort": "..."}` (not top-level)
4. Add `developer-instructions` with a role persona
5. Include `threadId` in the report output
6. Add a fallback section for when Codex is unavailable
7. Update `README.md` commands table
