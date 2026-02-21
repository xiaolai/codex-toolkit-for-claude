# codex-toolkit

OpenAI Codex MCP integration for Claude Code. Slash commands that delegate work to Codex running as an MCP server.

## Project structure

```
commands/           Slash command definitions (*.md with YAML frontmatter)
  shared/
    model-selection.md  Shared partial — dynamic model discovery (user-invocable: false)
  preflight.md        /preflight — connectivity + model check
  implement.md        /implement — autonomous plan execution
  audit.md            /audit — full 9-dimension code audit
  audit-mini.md       /audit-mini — fast 5-dimension audit
  verify.md           /verify — verify fixes from previous audit
  bug-analyze.md      /bug-analyze — root cause analysis
  review-plan.md      /review-plan — architectural plan review
  audit-fix.md        /audit-fix — audit→fix→verify loop
  continue.md         /continue — multi-turn follow-up via codex-reply
  init.md             /init — generate .codex-toolkit.md project config
scripts/
  codex-preflight.sh    Model discovery script (probes candidates in parallel)
.mcp.json               Registers Codex MCP server
.claude-plugin/
  plugin.json           Plugin metadata
  marketplace.json      Marketplace manifest for /plugin marketplace add
```

## Conventions

### MCP tool calls

- `model_reasoning_effort` MUST go inside the `config` object, not as a top-level parameter:
  ```
  config: {"model_reasoning_effort": "{chosen_effort}"}
  ```
- Every command that calls `mcp__codex__codex` MUST include `developer-instructions` with a role-specific persona.
- Every command report MUST include the `threadId` from the Codex response so users can follow up with `/continue`.
- Multi-step workflows (like audit→fix→verify) should **reuse the same thread** via `mcp__codex__codex-reply` when Codex is the actor, giving it cumulative context. Fall back to a fresh `mcp__codex__codex` call if the thread expires.
- Codex threads are **in-memory only** — lost on MCP server restart. Always include a fallback path.

### Project config (`.codex-toolkit.md`)

Users can run `/init` to generate a `.codex-toolkit.md` in their project root. This file is optional — all commands work without it.

When present, `commands/shared/model-selection.md` reads it at Step 0 and uses its values as defaults. Priority: user choice > project config > command defaults.

Config fields:
- **Default model/effort/sandbox** — override recommended values
- **Default audit type** — mini or full
- **Audit focus** — balanced, security-first, performance-first, quality-first
- **Skip patterns** — glob patterns to exclude from audits
- **Project-specific instructions** — appended to developer-instructions for all commands

### Command structure

All commands follow this pattern:
1. Load `.codex-toolkit.md` project config if it exists (Step 0)
2. Run `scripts/codex-preflight.sh` via `commands/shared/model-selection.md` to discover models
3. Present choices via `AskUserQuestion` (model, effort, optionally sandbox)
4. Ping Codex with a short availability test
5. Send the real task to Codex via `mcp__codex__codex`
6. If Codex fails or returns empty, fall back to manual analysis
7. Display structured report with threadId

### Model selection

- Models are discovered dynamically — never hardcode model availability
- The `commands/shared/model-selection.md` partial handles all model/effort/sandbox selection
- Each command specifies its recommended model, effort, and whether sandbox is relevant

### Adding new commands

1. Create `commands/<name>.md` with YAML frontmatter (`description`, optional `argument-hint`)
2. Reference `commands/shared/model-selection.md` for model selection
3. Use `config: {"model_reasoning_effort": "..."}` (not top-level)
4. Add `developer-instructions` with a role persona
5. Include `threadId` in the report output
6. Add a fallback section for when Codex is unavailable
7. Update `README.md` commands table
