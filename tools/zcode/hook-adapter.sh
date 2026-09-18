#!/usr/bin/env bash
# hook-adapter.sh — wrap a CCGS hook script's plain-text stdout into the JSON
# envelope ZCode expects for context injection.
#
# Why this exists: the CCGS SessionStart hooks (session-start.sh, detect-gaps.sh,
# post-compact.sh) print human-readable context to stdout. Claude Code injects
# that text into the conversation verbatim. ZCode parses hook stdout as strict
# JSON and injects context only via {"additionalContext": "..."} — plain text
# may be discarded. This adapter runs the original script unchanged (it stays
# shared with the Claude Code side) and wraps its stdout.
#
# Usage: hook-adapter.sh <script-path> [args...]
# Exit code: propagated from the wrapped script (non-zero skips wrapping).

set -uo pipefail

if [ $# -lt 1 ]; then
  echo "usage: hook-adapter.sh <script-path> [args...]" >&2
  exit 1
fi

OUT="$(bash "$@" 2>/dev/null)"
RC=$?

if [ $RC -ne 0 ]; then
  exit $RC
fi

# Empty output needs no envelope.
[ -z "$OUT" ] && exit 0

if command -v jq >/dev/null 2>&1; then
  printf '%s' "$OUT" | jq -Rs '{additionalContext: .}'
elif command -v python3 >/dev/null 2>&1; then
  printf '%s' "$OUT" | python3 -c 'import json,sys; print(json.dumps({"additionalContext": sys.stdin.read()}))'
else
  # Best effort: neither jq nor python3 available. Emit raw text — ZCode may
  # still surface it in the hook log, but context injection is not guaranteed.
  printf '%s\n' "$OUT"
fi
