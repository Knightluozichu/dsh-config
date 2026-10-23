#!/bin/sh
# Claude Code statusLine command
# Shows: model | basename(cwd) | git branch | context usage
# Receives Claude Code session JSON on stdin.

input=$(cat)

# --- Model (short display name) ---
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "claude"')

# --- Working directory (basename style) ---
cwd_full=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir_name=$(basename "$cwd_full")

# --- Git branch ---
branch=$(echo "$input" | jq -r '.worktree.branch // empty')
if [ -z "$branch" ]; then
  branch=$(git -C "$cwd_full" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# --- Git dirty indicator ---
if git -C "$cwd_full" --no-optional-locks diff --quiet 2>/dev/null && \
   git -C "$cwd_full" --no-optional-locks diff --cached --quiet 2>/dev/null; then
  dirty=""
else
  dirty="*"
fi

# --- Context window usage ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_part=""
if [ -n "$used" ]; then
  ctx_int=$(printf '%.0f' "$used")
  # Pick color: green <50, yellow 50-79, red >=80
  if [ "$ctx_int" -ge 80 ]; then
    ctx_color="\033[31m"
  elif [ "$ctx_int" -ge 50 ]; then
    ctx_color="\033[33m"
  else
    ctx_color="\033[32m"
  fi
  ctx_part=" ${ctx_color}ctx:${ctx_int}%\033[0m"
fi

# --- Assemble ---
# Format: [model] dir [branch*] ctx:xx%
# Colors: model=cyan, dir=bold-yellow, branch=blue, dirty=red

model_part="\033[36m${model}\033[0m"
dir_part="\033[1;33m${dir_name}\033[0m"

if [ -n "$branch" ]; then
  branch_part=" \033[34m${branch}\033[0m\033[31m${dirty}\033[0m"
else
  branch_part=""
fi

printf "[%s] %s%s%s" "$model_part" "$dir_part" "$branch_part" "$ctx_part"
