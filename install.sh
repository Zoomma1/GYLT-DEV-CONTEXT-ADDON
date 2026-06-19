#!/usr/bin/env bash
#
# GYLT addon installer (macOS / Linux) — generic, reads addon.json.
#
#   git clone <this addon>
#   cd <addon> && bash install.sh
#
# What it does:
#   1. Symlinks each skill folder into  <claude home>/skills/<name>
#   2. Symlinks each hook declared in addon.json into <claude home>/hooks/
#      and registers it under its event in <claude home>/settings.json (needs jq)
#   3. Seeds <claude home>/project-context-tools/ from project-context-tools/ if present
#
# Idempotent and non-destructive. Requires: bash, ln. Optional but recommended: jq.

set -euo pipefail

ADDON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MANIFEST="$ADDON_DIR/addon.json"

SKILLS_DST="$CLAUDE_HOME/skills"
HOOKS_DST="$CLAUDE_HOME/hooks"
TOOLS_DST="$CLAUDE_HOME/project-context-tools"
SETTINGS="$CLAUDE_HOME/settings.json"

mkdir -p "$SKILLS_DST" "$HOOKS_DST"

name="$(basename "$ADDON_DIR")"
[ -f "$MANIFEST" ] && command -v jq >/dev/null 2>&1 && \
  name="$(jq -r '.name // empty' "$MANIFEST" 2>/dev/null || echo "$name")"

echo ""
echo "$name — installing into $CLAUDE_HOME"
echo ""

# 1. Skills -----------------------------------------------------------------
echo "Skills:"
for d in "$ADDON_DIR"/skills/*/; do
  [ -d "$d" ] || continue
  sname="$(basename "$d")"
  dst="$SKILLS_DST/$sname"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "  - $sname : already present, skipped"
  else
    ln -s "$ADDON_DIR/skills/$sname" "$dst"
    echo "  - $sname : linked"
  fi
done

# 2. Hooks (declared in addon.json) -----------------------------------------
echo "Hooks:"
if [ -f "$MANIFEST" ] && command -v jq >/dev/null 2>&1; then
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  count="$(jq -r '.hooks // [] | length' "$MANIFEST")"
  if [ "$count" = "0" ]; then
    echo "  - none declared"
  fi
  i=0
  while [ "$i" -lt "$count" ]; do
    file="$(jq -r ".hooks[$i].file" "$MANIFEST")"
    event="$(jq -r ".hooks[$i].event" "$MANIFEST")"
    src="$ADDON_DIR/$file"
    base="$(basename "$file")"
    hdst="$HOOKS_DST/$base"
    chmod +x "$src" 2>/dev/null || true
    if [ -e "$hdst" ] || [ -L "$hdst" ]; then
      echo "  - $base : link already present"
    else
      ln -s "$src" "$hdst"
      echo "  - $base : linked"
    fi
    already="$(jq -r --arg c "$hdst" --arg e "$event" \
      '[.hooks[$e] // [] | .[].hooks[]? | select(.command == $c)] | length' \
      "$SETTINGS" 2>/dev/null || echo 0)"
    if [ "$already" != "0" ]; then
      echo "    $event already registered, skipped"
    else
      cp "$SETTINGS" "$SETTINGS.bak.$$"
      jq --arg c "$hdst" --arg e "$event" \
        '.hooks[$e] = ((.hooks[$e] // []) + [{"hooks":[{"type":"command","command":$c}]}])' \
        "$SETTINGS.bak.$$" > "$SETTINGS"
      echo "    $event registered (backup: $SETTINGS.bak.$$)"
    fi
    i=$((i + 1))
  done
else
  echo "  ! jq not found or no addon.json — register hooks in $SETTINGS manually."
fi

# 3. Seed project-context-tools (if the addon ships any) --------------------
if [ -d "$ADDON_DIR/project-context-tools" ]; then
  echo "Context-tools socket:"
  mkdir -p "$TOOLS_DST"
  # Seed everything: CONTRACT (doc), *.example.md (ignored by the skill), and active tools.
  for f in "$ADDON_DIR"/project-context-tools/*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    if [ -e "$TOOLS_DST/$base" ]; then
      echo "  - $base : already present, skipped"
    else
      cp "$f" "$TOOLS_DST/$base"
      echo "  - $base : copied"
    fi
  done
fi

echo ""
echo "Done. Restart Claude Code once so any SessionStart hook is picked up."
echo ""
