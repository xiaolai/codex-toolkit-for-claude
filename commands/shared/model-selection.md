---
user-invocable: false
---
<!-- Shared partial: dynamic model selection via codex-preflight -->
<!-- Referenced by all commands. Do not use as a standalone command. -->

## Model & Settings Selection

Before starting, discover which Codex models are currently available and check for project-specific configuration.

### Step 0: Load project config (if exists)

Check if `.codex-toolkit.md` exists in the current working directory. If it does, read it and extract these variables:

- `{config_default_model}` — Default model
- `{config_default_effort}` — Default effort
- `{config_default_sandbox}` — Default sandbox
- `{config_default_audit_type}` — Default audit type (mini or full)
- `{config_focus_instructions}` — Audit Focus additional instructions text
- `{config_skip_patterns}` — Skip patterns (glob list)
- `{config_project_instructions}` — Project-Specific Instructions text

If `.codex-toolkit.md` does not exist, leave all variables empty and use the calling command's built-in defaults. Do NOT ask the user to run `/init` — it's optional.

**Priority order** (highest wins):
1. User's explicit choice (from AskUserQuestion)
2. Project config (`.codex-toolkit.md`)
3. Command's built-in defaults

### Step A: Run preflight discovery

Run the preflight script to probe available models:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/codex-preflight.sh"
```

Parse the JSON output. The structure is:

```json
{
  "status": "ok",
  "codex_version": "0.101.0",
  "auth_mode": "chatgpt_login",
  "codex_cloud": false,
  "models": ["gpt-5.3-codex", "gpt-5.2-codex", ...],
  "unavailable": ["gpt-5-codex-mini", ...],
  "reasoning_efforts": ["low", "medium", "high"],
  "sandbox_levels": ["read-only", "workspace-write", "danger-full-access"]
}
```

### Step B: Handle errors

- If `status` is `"error"` → display the `error` message to the user and **STOP**. Common fixes:
  - `"codex CLI not found"` → tell user to run `npm install -g @openai/codex`
  - `"Not authenticated"` → tell user to run `codex login`
- If `models` is an empty array → tell user "No Codex models are currently available. Check your account/subscription and try `codex login`." and **STOP**.

### Step C: Present choices via AskUserQuestion

Build the `AskUserQuestion` options **dynamically** from the preflight results. Ask all questions at once:

**Question 1 — Model** (from `models` array):

Build the option list from the available models. Use these descriptions when known (fall back to using the model name as-is for any model not listed here):

| Model | Description |
|-------|-------------|
| `gpt-5.4` | Latest frontier — most capable agentic coding model |
| `gpt-5.3-codex` | Previous flagship — strong reasoning + coding |
| `gpt-5.3-codex-spark` | Ultra-low-latency real-time iteration (Pro only) |
| `gpt-5.2-codex` | Previous gen — good balance of speed and cost |
| `gpt-5.2` | GPT-5.2 base |
| `gpt-5.1-codex-max` | Long-horizon, large codebases |
| `gpt-5.1-codex` | GPT-5.1 Codex |
| `gpt-5.1` | GPT-5.1 base |
| `gpt-5-codex` | GPT-5 Codex |
| `gpt-5` | GPT-5 base |
| `gpt-5.1-codex-mini` | Mini variant — fast and cheap |
| `gpt-5-codex-mini` | Fastest, cheapest |
| `o4-mini` | Fast reasoning model |
| `o3` | Strong reasoning model |
| `codex-mini-latest` | Latest mini variant |
| `gpt-4.1` | GPT-4.1 |
| `gpt-4.1-mini` | GPT-4.1 Mini — lightweight |

For any model not in this table, use the model name as the description.

**Determining the recommended model**:
1. If `{config_default_model}` is set AND it's in the available list → use that
2. Otherwise, use the calling command's recommended model (if available)
3. If neither is available, mark the first available model as recommended

**Question 2 — Reasoning effort:**

| Level | Best for |
|-------|----------|
| `low` | Simple/mechanical tasks, quick checks |
| `medium` | Standard tasks — balanced speed and depth |
| `high` | Complex tasks — thorough, catches subtle issues |

Mark `{config_default_effort}` as "(Recommended)" if set, otherwise use the calling command's recommendation.

**Question 3 — Sandbox level** (only if the calling command uses sandbox):

| Level | Permissions |
|-------|-------------|
| `read-only` | Read-only, no file changes (dry run) |
| `workspace-write` | Write only within the working directory |
| `danger-full-access` | Full read/write/execute everywhere |

Mark `{config_default_sandbox}` as "(Recommended)" if set, otherwise use the calling command's recommendation.

### Step D: Apply project config to Codex calls

After the user makes their choices, when building the `mcp__codex__codex` call, you MUST apply config values as follows:

1. **developer-instructions**: Start with the command's role persona, then MUST append:
   - `{config_focus_instructions}` (if non-empty)
   - `{config_project_instructions}` (if non-empty)

   These are NOT optional — if the config provides them, they MUST be included in every Codex call's developer-instructions.

2. **Skip patterns**: Before sending files to Codex, you MUST filter out any files matching `{config_skip_patterns}`. If all files are filtered out, report that and stop.

See `commands/shared/codex-call.md` for the canonical call pattern that enforces these rules.
