#!/usr/bin/env bash
# sync.sh — generate the ZCode adapter layer (.zcode/) from the Claude Code
# source of truth (.claude/).
#
# Transforms:
#   agents: strip Claude-specific frontmatter keys (model, memory, isolation).
#           The rest (name, description, tools, disallowedTools, maxTurns,
#           skills) is parsed and enforced natively by ZCode.
#   skills: keep only the name/description frontmatter (ZCode recognizes
#           name, description, when_to_use, license, metadata; other keys such
#           as allowed-tools/argument-hint/model/user-invocable/agent/context/
#           isolation are Claude-specific and inert on ZCode), and rename
#           code-review -> ccgs-code-review so a personal user-scope skill
#           named code-review cannot shadow it.
#
# Skill and agent bodies are copied verbatim — never edited here — so upstream
# merges into .claude/ stay conflict-free. Re-run this script after any
# upstream merge, then commit the regenerated .zcode/ tree.
#
# .zcode/config.json, AGENTS.md, tools/zcode/hook-adapter.sh and
# tools/zcode/guard-deny.sh are hand-maintained and never touched by this run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENTS_SRC="$ROOT/.claude/agents"
AGENTS_DST="$ROOT/.zcode/agents"
SKILLS_SRC="$ROOT/.claude/skills"
SKILLS_DST="$ROOT/.zcode/skills"

[ -d "$AGENTS_SRC" ] || { echo "error: $AGENTS_SRC not found" >&2; exit 1; }
[ -d "$SKILLS_SRC" ] || { echo "error: $SKILLS_SRC not found" >&2; exit 1; }

# --- agents ------------------------------------------------------------------
rm -rf "$AGENTS_DST"
mkdir -p "$AGENTS_DST"
for f in "$AGENTS_SRC"/*.md; do
  awk '
    /^---$/ { fm++; print; next }
    fm == 1 && /^(model|memory|isolation):/ { next }
    { print }
  ' "$f" > "$AGENTS_DST/$(basename "$f")"
done

# --- skills ------------------------------------------------------------------
rm -rf "$SKILLS_DST"
mkdir -p "$SKILLS_DST"
for d in "$SKILLS_SRC"/*/; do
  name="$(basename "$d")"
  dst_name="$name"
  rename=""
  if [ "$name" = "code-review" ]; then
    dst_name="ccgs-code-review"
    rename="ccgs-code-review"
  fi
  mkdir -p "$SKILLS_DST/$dst_name"
  awk -v rename="$rename" '
    function fm_name(line,  v) {
      v = line; sub(/^name:[ ]*/, "", v)
      if (rename != "") v = rename
      return "name: " v
    }
    /^---$/ { fm++; print; next }
    fm == 1 {
      if ($0 ~ /^name:/) { print fm_name($0); next }
      if ($0 ~ /^description:/) { print; next }
      next
    }
    { print }
  ' "$d/SKILL.md" > "$SKILLS_DST/$dst_name/SKILL.md"
done

agent_count="$(find "$AGENTS_DST" -name '*.md' | wc -l | tr -d ' ')"
skill_count="$(find "$SKILLS_DST" -name 'SKILL.md' | wc -l | tr -d ' ')"
echo "Generated $agent_count agents in .zcode/agents"
echo "Generated $skill_count skills in .zcode/skills"

src_agents="$(find "$AGENTS_SRC" -name '*.md' | wc -l | tr -d ' ')"
src_skills="$(find "$SKILLS_SRC" -name 'SKILL.md' | wc -l | tr -d ' ')"
if [ "$agent_count" != "$src_agents" ] || [ "$skill_count" != "$src_skills" ]; then
  echo "warning: count mismatch (source: $src_agents agents / $src_skills skills)" >&2
  exit 1
fi
