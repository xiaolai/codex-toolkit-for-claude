---
description: Show active and recent Codex jobs — background tasks, running audits, completed results
argument-hint: "[job-id] [--all] [--json]"
---

## User Input

```text
$ARGUMENTS
```

## Workflow

### Step 1: Build status snapshot

Run the status script to gather job state:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-status.mjs" $ARGUMENTS
```

If the script is not yet available, build the status manually:

1. Read the state file from the workspace state directory
2. Filter jobs for the current session (unless `--all` flag is present)
3. Sort by most recent first

### Step 2: Display status

Parse `$ARGUMENTS`:

| Input | Action |
|-------|--------|
| (empty) | Show all jobs for current session |
| `<job-id>` | Show details for a specific job |
| `--all` | Show all jobs across all sessions |
| `--json` | Output raw JSON instead of markdown |

#### Default view (no job-id)

```markdown
# Codex Toolkit Status

Review gate: {enabled / disabled}

## Active Jobs

| Job | Kind | Status | Phase | Elapsed | Thread ID | Summary |
| --- | --- | --- | --- | --- | --- | --- |
| {id} | {kind} | running | {phase} | {elapsed} | {threadId} | {summary} |

## Latest Finished

- {id} | {status} | {kind}
  Summary: {summary}
  Duration: {duration}
  Thread ID: {threadId}
  Continue: /continue {threadId}
  Result: /codex-toolkit:result {id}

## Recent Jobs

{list of recent completed/failed jobs}
```

If no jobs exist: "No jobs recorded yet. Run /audit, /implement, or /bug-analyze to create one."

#### Single job view (job-id provided)

Show detailed info for the specific job including progress preview lines if running.

### Step 3: Review gate status

If the stop-time review gate is enabled, append:

```
The stop-time review gate is enabled.
Ending the session will trigger a Codex adversarial review and block if it finds issues.
Disable with: /codex-toolkit:setup --disable-review-gate
```
