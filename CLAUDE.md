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
    plugin-discover.md  Shared partial — plugin artifact discovery for plugin directories (user-invocable: false)
  preflight.md        /preflight — connectivity + model check
  implement.md        /implement — autonomous plan execution
  audit.md            /audit — code audit (--full 9-dim or --mini 5-dim)
  verify.md           /verify — verify fixes from previous audit
  bug-analyze.md      /bug-analyze — root cause analysis
  review-plan.md      /review-plan — architectural plan review
  audit-fix.md        /audit-fix — audit→fix→verify loop
  audit-plugin.md     /audit-plugin — plugin artifact audit (schema, spec, security, structure)
  audit-skill.md      /audit-skill — skill SKILL.md audit (triggers, content, context efficiency)
  audit-command.md    /audit-command — command .md audit (workflow, tools, error handling)
  audit-rules.md      /audit-rules — .claude/rules/ audit (enforceability, budget, conflicts)
  audit-agent.md      /audit-agent — agent .md audit (triggering, system prompt, tools, safety)
  audit-nlp.md        /audit-nlp — repo-wide NL programming audit (prompts, agents, skills, rules, specs)
  refresh-knowledge.md /refresh-knowledge — fetch latest Claude Code docs, update convention skill
  continue.md         /continue — multi-turn follow-up via codex-reply
  init.md             /init — generate .codex-toolkit.md project config
agents/
  cross-validator.md  Cross-validate Codex audit findings against Claude's native knowledge
skills/
  codex-toolkit/
    claude-code-conventions/
      SKILL.md        Canonical Claude Code artifact schemas, injected into Codex developer-instructions
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
- **plugin-discover.md** → plugin root resolution, manifest validation, artifact discovery, cross-reference map, inventory summary

Config enforcement chain: `model-selection.md` (extracts config variables) → `codex-call.md` (applies them to calls) → `scope-parse.md` (applies skip patterns to files).

Commands that share logic with another command should reference it rather than duplicate. For example, `audit-fix.md` references `audit.md` Step 1 for audit-type selection instead of inlining the same block.

### Project config (`.codex-toolkit.md`)

Users can run `/init` to generate a `.codex-toolkit.md` in their project root. This file is optional — all commands work without it.

When present, `commands/shared/model-selection.md` reads it at Step 0 and extracts variables: `{config_default_model}`, `{config_default_effort}`, `{config_default_sandbox}`, `{config_default_audit_type}`, `{config_focus_instructions}`, `{config_skip_patterns}`, `{config_project_instructions}`.

Priority: user choice > project config > command defaults.

### Command structure

Most commands follow this pattern:
1. Load `.codex-toolkit.md` project config if it exists (via model-selection.md Step 0)
2. Run `scripts/codex-preflight.sh` via model-selection.md to discover models
3. Present choices via `AskUserQuestion` (model, effort, optionally sandbox)
4. Ping Codex with availability test (via codex-call.md)
5. Send the real task to Codex via `mcp__codex__codex` (via codex-call.md)
6. If Codex fails or returns empty, fall back to manual analysis (via fallback.md)
7. Display structured report with threadId

Exceptions: `preflight.md` (IS the preflight step, no model selection), `audit-plugin.md` (does direct analysis without Codex — plugin artifacts are small enough and Codex can't read local files in read-only sandbox).

### Cross-provider knowledge architecture

Codex (OpenAI) has no native knowledge of Claude Code conventions. The plugin solves this with three layers:

1. **Skill as knowledge base**: `skills/codex-toolkit/claude-code-conventions/SKILL.md` is the single source of truth for Claude Code schemas, events, and conventions. The `codex-call.md` partial injects this content into Codex's `developer-instructions` for plugin-audit commands.

2. **Knowledge refresh**: `/refresh-knowledge` fetches latest Claude Code docs via context7 MCP and compares against the skill. `--check` for drift report, `--update` to apply changes.

3. **Cross-validation**: The `cross-validator` agent uses Claude's native Claude Code knowledge to verify Codex's audit findings. Dispatched after audit commands to catch false positives and hallucinated conventions.

**Flow**: refresh-knowledge updates skill → codex-call injects skill into Codex → Codex audits → cross-validator verifies.

### Adding new commands

1. Create `commands/<name>.md` with YAML frontmatter (`description`, optional `argument-hint`)
2. Reference `commands/shared/model-selection.md` for model selection
3. Reference `commands/shared/codex-call.md` for availability test and call pattern
4. Reference `commands/shared/scope-parse.md` if the command takes file/scope arguments
5. Reference `commands/shared/fallback.md` if manual fallback is needed
6. Include `threadId` in the report output
7. Update `README.md` commands table
