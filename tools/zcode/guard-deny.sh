#!/usr/bin/env bash
# guard-deny.sh — ZCode adaptation of the CCGS .claude/settings.json "deny"
# permission list (ZCode has no workspace-level permission rules; a PreToolUse
# hook with exit code 2 provides equivalent, non-bypassable blocking).
#
# PreToolUse hook: exit 0 = allow, exit 2 = block (reason on stderr).
# Input schema (stdin JSON):
#   Bash: { "tool_name": "Bash", "tool_input": { "command": "..." } }
#   Read: { "tool_name": "Read", "tool_input": { "file_path": "..." } }
#
# Replicates (from .claude/settings.json permissions.deny):
#   Bash(rm -rf *)            Bash(git push --force*) / Bash(git push -f *)
#   Bash(git reset --hard*)   Bash(git clean -f*)
#   Bash(sudo *)              Bash(chmod 777*)
#   Bash(*>.env*)             Bash(cat *.env*) / Bash(type *.env*)
#   Read(**/.env*)
# Note: git push --force-with-lease is intentionally NOT blocked (safer than a
# blind force push; the Claude glob blocked it only as a side effect).

INPUT=$(cat)

# Parse stdin JSON — jq if available, grep fallback (same style as CCGS hooks)
if command -v jq >/dev/null 2>&1; then
  TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
else
  TOOL=$(printf '%s' "$INPUT" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"tool_name"[[:space:]]*:[[:space:]]*"//;s/"$//')
  CMD=$(printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
  FILE_PATH=$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

block() {
  echo "guard-deny (CCGS safety rule): $1" >&2
  exit 2
}

# Read tool: block .env files — deny: Read(**/.env*)
if [ "$TOOL" = "Read" ] && [ -n "$FILE_PATH" ]; then
  base="$(basename "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")"
  case "$base" in
    .env*) block "reading $FILE_PATH is denied (.env files are off-limits)" ;;
  esac
fi

# Bash tool: replicate the deny patterns
if [ "$TOOL" = "Bash" ] && [ -n "$CMD" ]; then
  echo "$CMD" | grep -qE '(^|[;&|(][[:space:]]*|&&[[:space:]]*|\|[[:space:]]*)rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[[:space:]]' \
    && block "rm -rf is denied"
  echo "$CMD" | grep -qE 'git[[:space:]]+push([[:space:]]+[^;&|]*)?[[:space:]]+(--force([[:space:]]|$)|-f([[:space:]]|$))' \
    && block "force push is denied (use --force-with-lease if you must)"
  echo "$CMD" | grep -qE 'git[[:space:]]+push[[:space:]]+(-f([[:space:]]|$)|--force([[:space:]]|$))' \
    && block "force push is denied (use --force-with-lease if you must)"
  echo "$CMD" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard' \
    && block "git reset --hard is denied"
  echo "$CMD" | grep -qE 'git[[:space:]]+clean[[:space:]]+[^;&|]*(-f|--force)' \
    && block "git clean -f is denied"
  echo "$CMD" | grep -qE '(^|[;&|(][[:space:]]*)sudo([[:space:]]|$)' \
    && block "sudo is denied"
  echo "$CMD" | grep -qE '(^|[;&|(][[:space:]]*)chmod[[:space:]]+777' \
    && block "chmod 777 is denied"
  echo "$CMD" | grep -qE '>{1,2}[[:space:]]*([^;&|]*[/[:space:]])?\.env' \
    && block "redirecting output to .env files is denied"
  echo "$CMD" | grep -qE '(^|[;&|(][[:space:]]*)(cat|type)[[:space:]]+[^;&|]*\.env' \
    && block "reading .env files via cat/type is denied"
fi

exit 0
