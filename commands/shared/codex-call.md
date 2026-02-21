---
user-invocable: false
---
<!-- Shared partial: Codex call pattern (availability test, developer-instructions builder, call, thread handling) -->
<!-- Referenced by: audit, audit-fix, verify, bug-analyze, review-plan, implement. Do not use standalone. -->

## Codex Call Pattern

### Availability Test

Before the real Codex call, send a short ping:

```
mcp__codex__codex with:
  prompt: "Respond with 'ok' if you can read this."
  model: {chosen_model}
  config: {"model_reasoning_effort": "{chosen_effort}"}
```

If Codex does not respond or errors out, skip to the calling command's **Fallback** section immediately. Do not retry.

### Build developer-instructions

Concatenate these parts into a single `developer-instructions` string:

1. **Command persona** — the role-specific persona from the calling command (e.g. "You are a thorough security and code quality auditor.")
2. **Config focus instructions** — `{config_focus_instructions}` from `.codex-toolkit.md` Audit Focus section (if present)
3. **Config project instructions** — `{config_project_instructions}` from `.codex-toolkit.md` Project-Specific Instructions section (if present)

If parts 2 or 3 are empty, omit them. Separate non-empty parts with a single space.

### Canonical mcp__codex__codex call

```
mcp__codex__codex with:
  model: {chosen_model}
  config: {"model_reasoning_effort": "{chosen_effort}"}
  sandbox: {chosen_sandbox or command default}
  approval-policy: {command default, usually "never"}
  developer-instructions: "{built developer-instructions string}"
  prompt: "{command-specific prompt}"
```

**IMPORTANT**: `model_reasoning_effort` MUST go inside the `config` object, never as a top-level parameter.

### Thread Handling

1. **Save the `threadId`** from every Codex response. Include it in the final report so the user can follow up with `/continue {threadId}`.
2. **Reuse threads** in multi-step workflows (audit→fix→verify) via `mcp__codex__codex-reply` to give Codex cumulative context.
3. **Fallback**: If `codex-reply` fails (thread expired, MCP server restarted), fall back to a fresh `mcp__codex__codex` call with the same parameters. Update `{threadId}` to the new value.
4. Codex threads are **in-memory only** — lost on MCP server restart.

### Sequential Execution

Run Codex calls **one at a time**. Wait for each call to complete before starting the next. Do NOT run multiple Codex calls in parallel.
