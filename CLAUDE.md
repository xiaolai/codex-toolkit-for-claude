# codex-toolkit

OpenAI Codex MCP integration for Claude Code. Slash commands that delegate work to Codex running as an MCP server.

## Project structure

```
commands/           Slash command definitions (*.md with YAML frontmatter)
  shared/
    model-selection.md  Shared partial — dynamic model discovery (user-invocable: false)
    codex-call.md       Shared partial — availability test, call pattern, thread handling (user-invocable: false)
    scope-parse.md      Shared partial — scope parsing, trivial check, skip patterns (user-invocable: false)
    fallback.md         Shared partial — manual fallback rules (user-invocable: false)
  preflight.md        /preflight — connectivity + model check
  implement.md        /implement — autonomous plan execution
  audit.md            /audit — code audit (--full 9-dim or --mini 5-dim)
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

### Shared partials

Commands reference shared partials to eliminate boilerplate:

- **model-selection.md** → loads `.codex-toolkit.md` config, runs preflight, presents model/effort/sandbox choices
- **codex-call.md** → availability test (ping), developer-instructions builder (persona + config focus + config project instructions), canonical call pattern, thread handling, sequential execution rule
- **scope-parse.md** → unified scope parsing table, skip pattern enforcement against `{config_skip_patterns}`, trivial scope check with AskUserQuestion
- **fallback.md** → universal "if Codex fails, do it manually" rules

Config enforcement chain: `model-selection.md` (extracts config variables) → `codex-call.md` (applies them to calls) → `scope-parse.md` (applies skip patterns to files).

### Project config (`.codex-toolkit.md`)

Users can run `/init` to generate a `.codex-toolkit.md` in their project root. This file is optional — all commands work without it.

When present, `commands/shared/model-selection.md` reads it at Step 0 and extracts variables: `{config_default_model}`, `{config_default_effort}`, `{config_default_sandbox}`, `{config_default_audit_type}`, `{config_focus_instructions}`, `{config_skip_patterns}`, `{config_project_instructions}`.

Priority: user choice > project config > command defaults.

### Command structure

All commands follow this pattern:
1. Load `.codex-toolkit.md` project config if it exists (via model-selection.md Step 0)
2. Run `scripts/codex-preflight.sh` via model-selection.md to discover models
3. Present choices via `AskUserQuestion` (model, effort, optionally sandbox)
4. Ping Codex with availability test (via codex-call.md)
5. Send the real task to Codex via `mcp__codex__codex` (via codex-call.md)
6. If Codex fails or returns empty, fall back to manual analysis (via fallback.md)
7. Display structured report with threadId

### Adding new commands

1. Create `commands/<name>.md` with YAML frontmatter (`description`, optional `argument-hint`)
2. Reference `commands/shared/model-selection.md` for model selection
3. Reference `commands/shared/codex-call.md` for availability test and call pattern
4. Reference `commands/shared/scope-parse.md` if the command takes file/scope arguments
5. Reference `commands/shared/fallback.md` if manual fallback is needed
6. Include `threadId` in the report output
7. Update `README.md` commands table
