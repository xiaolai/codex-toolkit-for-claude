#!/usr/bin/env bash
# codex-preflight.sh — Discover available Codex models from the local models cache.
#
# Usage:  bash scripts/codex-preflight.sh
# Output: JSON to stdout  (human summary to stderr)
#
# Caching: Results are cached for 5 minutes in $TMPDIR/codex-preflight-cache.json.
#          Set CODEX_PREFLIGHT_NO_CACHE=1 to skip cache.
#
# How it works:
#   Reads ~/.codex/models_cache.json (maintained by the codex CLI) to get the
#   list of available models. No hardcoded model names — new models appear
#   automatically after `codex login` refreshes the cache.
#   Falls back to probing if models_cache.json is missing or stale.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────

PROBE_TIMEOUT=5          # seconds to wait before declaring "available" (fallback only)
CLOUD_TIMEOUT=5          # seconds to wait for codex cloud list
CACHE_TTL=300            # seconds (5 minutes) for our own preflight cache
MODELS_CACHE_MAX_AGE=86400  # 24h — if models_cache.json is older, fall back to probing
PROBE_PROMPT="Respond with ok."

# Fallback candidate models — used ONLY when ~/.codex/models_cache.json is
# missing or too stale. Keep this list as a safety net.
FALLBACK_MODELS=(
  gpt-5.4-codex
  gpt-5.3-codex
  gpt-5.3-codex-spark
  gpt-5.1-codex-max
  gpt-5-codex-mini
  o4-mini
  o3
  codex-mini-latest
)

# Static options (stable CLI flags — no need to probe).
REASONING_EFFORTS='["low","medium","high"]'
SANDBOX_LEVELS='["read-only","workspace-write","danger-full-access"]'

# ── Helpers ──────────────────────────────────────────────────────────────────

info() { echo "$*" >&2; }

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

resolve_timeout_cmd() {
  if command -v timeout &>/dev/null; then
    echo "timeout"
  elif command -v gtimeout &>/dev/null; then
    echo "gtimeout"
  else
    echo ""
  fi
}

json_array() {
  if [[ $# -eq 0 ]]; then
    echo "[]"
    return
  fi
  local result="["
  local first=true
  for item in "$@"; do
    if $first; then first=false; else result+=","; fi
    result+="\"$item\""
  done
  result+="]"
  echo "$result"
}

file_age_seconds() {
  local file="$1"
  if [[ "$(uname)" == "Darwin" ]]; then
    echo $(( $(date +%s) - $(stat -f %m "$file") ))
  else
    echo $(( $(date +%s) - $(stat -c %Y "$file") ))
  fi
}

# ── Step 0: Check our own preflight cache ────────────────────────────────────

CACHE_FILE="${TMPDIR:-/tmp}/codex-preflight-cache.json"

if [[ -z "${CODEX_PREFLIGHT_NO_CACHE:-}" && -f "$CACHE_FILE" ]]; then
  cache_age=$(file_age_seconds "$CACHE_FILE")
  if [[ $cache_age -lt $CACHE_TTL ]]; then
    info "Using cached results (${cache_age}s old, TTL ${CACHE_TTL}s)"
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# ── Step 1: Check codex CLI ──────────────────────────────────────────────────

if ! command -v codex &>/dev/null; then
  cat <<'JSON'
{"status":"error","error":"codex CLI not found. Install: npm install -g @openai/codex","models":[],"reasoning_efforts":[],"sandbox_levels":[]}
JSON
  exit 1
fi

# ── Step 2: Get codex version ────────────────────────────────────────────────

CODEX_VERSION=$(codex --version 2>/dev/null || echo "unknown")
info "Codex version: $CODEX_VERSION"

# ── Step 3: Check authentication ─────────────────────────────────────────────

AUTH_MODE="unknown"

LOGIN_STATUS=$(codex login status 2>&1) || true
if echo "$LOGIN_STATUS" | grep -qi "logged in"; then
  if echo "$LOGIN_STATUS" | grep -qi "chatgpt"; then
    AUTH_MODE="chatgpt_login"
  elif echo "$LOGIN_STATUS" | grep -qi "api.key\|api_key"; then
    AUTH_MODE="api_key"
  else
    AUTH_MODE="authenticated"
  fi
elif echo "$LOGIN_STATUS" | grep -qi "not logged in\|not authenticated"; then
  AUTH_MODE="unknown"
else
  AUTH_FILE="$HOME/.codex/auth.json"
  if [[ -f "$AUTH_FILE" ]]; then
    if command -v jq &>/dev/null; then
      AUTH_MODE=$(jq -r '.auth_mode // "unknown"' "$AUTH_FILE" 2>/dev/null || echo "unknown")
    else
      AUTH_MODE=$(grep -o '"auth_mode"[[:space:]]*:[[:space:]]*"[^"]*"' "$AUTH_FILE" 2>/dev/null \
        | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || echo "unknown")
    fi
  fi
fi

if [[ "$AUTH_MODE" == "unknown" && -n "${OPENAI_API_KEY:-}" ]]; then
  AUTH_MODE="api_key"
fi

if [[ "$AUTH_MODE" == "unknown" ]]; then
  CODEX_VERSION_SAFE=$(json_escape "$CODEX_VERSION")
  cat <<JSON
{"status":"error","error":"Not authenticated. Run: codex login","auth_mode":"none","codex_version":"$CODEX_VERSION_SAFE","models":[],"reasoning_efforts":$REASONING_EFFORTS,"sandbox_levels":$SANDBOX_LEVELS}
JSON
  exit 1
fi

info "Auth mode: $AUTH_MODE"

# ── Step 4: Read models from ~/.codex/models_cache.json ──────────────────────

MODELS_CACHE="$HOME/.codex/models_cache.json"
USE_CACHE=false

if [[ -f "$MODELS_CACHE" ]]; then
  cache_age=$(file_age_seconds "$MODELS_CACHE")
  if [[ $cache_age -lt $MODELS_CACHE_MAX_AGE ]]; then
    USE_CACHE=true
    info "Reading models from ~/.codex/models_cache.json (${cache_age}s old)"
  else
    info "Models cache too stale (${cache_age}s > ${MODELS_CACHE_MAX_AGE}s), falling back to probing"
  fi
else
  info "No models_cache.json found, falling back to probing"
fi

AVAILABLE=()

if $USE_CACHE; then
  # Extract model slugs from the cache using python3 (always available on macOS/Linux)
  # Falls back to jq, then to grep-based parsing
  if command -v python3 &>/dev/null; then
    while IFS= read -r slug; do
      [[ -n "$slug" ]] && AVAILABLE+=("$slug")
    done < <(python3 -c "
import json, sys
try:
    with open('$MODELS_CACHE') as f:
        data = json.load(f)
    for m in data.get('models', []):
        slug = m.get('slug', '')
        if slug:
            print(slug)
except Exception:
    sys.exit(1)
" 2>/dev/null)
  elif command -v jq &>/dev/null; then
    while IFS= read -r slug; do
      [[ -n "$slug" ]] && AVAILABLE+=("$slug")
    done < <(jq -r '.models[].slug // empty' "$MODELS_CACHE" 2>/dev/null)
  else
    # Fallback: simple grep extraction (less reliable but works without dependencies)
    while IFS= read -r slug; do
      [[ -n "$slug" ]] && AVAILABLE+=("$slug")
    done < <(grep -o '"slug"[[:space:]]*:[[:space:]]*"[^"]*"' "$MODELS_CACHE" 2>/dev/null \
      | sed 's/.*"\([^"]*\)"$/\1/')
  fi

  if [[ ${#AVAILABLE[@]} -eq 0 ]]; then
    info "Warning: models_cache.json parsed but no models found, falling back to probing"
    USE_CACHE=false
  else
    info "Found ${#AVAILABLE[@]} models from cache"
    for model in "${AVAILABLE[@]}"; do
      info "  $model"
    done
  fi
fi

# ── Step 4b: Fallback — probe models in parallel (only if cache unavailable) ─

UNAVAILABLE=()

if ! $USE_CACHE; then
  info "Probing ${#FALLBACK_MODELS[@]} fallback models (timeout ${PROBE_TIMEOUT}s each)..."

  TMPDIR_PROBE=$(mktemp -d)
  trap 'kill 0 2>/dev/null; rm -rf "$TMPDIR_PROBE"' EXIT

  TIMEOUT_CMD=$(resolve_timeout_cmd)

  probe_model() {
    local model="$1"
    local outfile="$TMPDIR_PROBE/$model"
    local stderr_file="$TMPDIR_PROBE/${model}.stderr"

    if [[ -n "$TIMEOUT_CMD" ]]; then
      $TIMEOUT_CMD "$PROBE_TIMEOUT" \
        codex exec -m "$model" "$PROBE_PROMPT" \
        >"$outfile" 2>"$stderr_file" &
    else
      (
        codex exec -m "$model" "$PROBE_PROMPT" \
          >"$outfile" 2>"$stderr_file"
      ) &
      local pid=$!
      (
        sleep "$PROBE_TIMEOUT"
        kill "$pid" 2>/dev/null
      ) &
      local killer=$!
      wait "$pid" 2>/dev/null
      kill "$killer" 2>/dev/null
      wait "$killer" 2>/dev/null
    fi
  }

  for model in "${FALLBACK_MODELS[@]}"; do
    probe_model "$model" &
  done

  wait

  for model in "${FALLBACK_MODELS[@]}"; do
    stderr_file="$TMPDIR_PROBE/${model}.stderr"
    if [[ -f "$stderr_file" ]] && grep -qi "not supported" "$stderr_file" 2>/dev/null; then
      UNAVAILABLE+=("$model")
      info "  $model  -->  unavailable"
    else
      AVAILABLE+=("$model")
      info "  $model  -->  available"
    fi
  done
fi

# ── Step 5: Check Codex Cloud availability ───────────────────────────────────

CODEX_CLOUD="false"
TIMEOUT_CMD=$(resolve_timeout_cmd)
if [[ -n "$TIMEOUT_CMD" ]]; then
  if $TIMEOUT_CMD "$CLOUD_TIMEOUT" codex cloud list &>/dev/null; then
    CODEX_CLOUD="true"
  fi
else
  info "  Skipping cloud check (no timeout command available)"
fi

# ── Step 6: Output JSON ─────────────────────────────────────────────────────

available_json=$(json_array "${AVAILABLE[@]+"${AVAILABLE[@]}"}")
unavailable_json=$(json_array "${UNAVAILABLE[@]+"${UNAVAILABLE[@]}"}")

CODEX_VERSION_SAFE=$(json_escape "$CODEX_VERSION")
AUTH_MODE_SAFE=$(json_escape "$AUTH_MODE")

OUTPUT=$(cat <<JSON
{"status":"ok","codex_version":"$CODEX_VERSION_SAFE","auth_mode":"$AUTH_MODE_SAFE","codex_cloud":$CODEX_CLOUD,"models":$available_json,"unavailable":$unavailable_json,"reasoning_efforts":$REASONING_EFFORTS,"sandbox_levels":$SANDBOX_LEVELS}
JSON
)

echo "$OUTPUT" > "$CACHE_FILE"
echo "$OUTPUT"
