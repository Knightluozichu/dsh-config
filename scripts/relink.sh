#!/usr/bin/env bash
# 在目标机（macOS / Linux）重建 ~/.agents/skills 下的插件软链接。
# Windows 上的 junction 无法随 git 复制，必须在此重建。
# 用法：bash scripts/relink.sh [--check]
set -euo pipefail

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

SKILLS_DIR="${HOME}/.agents/skills"
PONYTAIL_ROOT_DEFAULT="${HOME}/.codex/plugins/cache/ponytail"
UNDERSTAND_ROOT_DEFAULT="${HOME}/.understand-anything/repo/understand-anything-plugin/skills"

PONYTAIL_ROOT="${PONYTAIL_ROOT:-$PONYTAIL_ROOT_DEFAULT}"
UNDERSTAND_ROOT="${UNDERSTAND_ROOT:-$UNDERSTAND_ROOT_DEFAULT}"

log() { printf '  %s\n' "$*"; }

# 找到 ponytail 最高版本目录下的 skills/
find_ponytail_skills() {
  local base="$PONYTAIL_ROOT"
  [[ -d "$base" ]] || return 1
  local cand
  cand=$(find "$base" -mindepth 2 -maxdepth 2 -type d -name skills 2>/dev/null | sort -V | tail -n 1)
  [[ -n "$cand" ]] && printf '%s' "$cand"
}

PONYTAIL_SKILLS="$(find_ponytail_skills || true)"

link_pairs=()
if [[ -n "$PONYTAIL_SKILLS" ]]; then
  for n in ponytail ponytail-audit ponytail-debt ponytail-gain ponytail-help ponytail-review; do
    [[ -d "$PONYTAIL_SKILLS/$n" ]] && link_pairs+=("$n:$PONYTAIL_SKILLS/$n")
  done
else
  log "未找到 ponytail 插件源（$PONYTAIL_ROOT），跳过 $((0)) 个链接"
fi

if [[ -d "$UNDERSTAND_ROOT" ]]; then
  for n in understand understand-chat understand-dashboard understand-diff understand-domain \
           understand-explain understand-figma understand-knowledge understand-onboard; do
    [[ -d "$UNDERSTAND_ROOT/$n" ]] && link_pairs+=("$n:$UNDERSTAND_ROOT/$n")
  done
else
  log "未找到 understand-anything 源（$UNDERSTAND_ROOT），跳过"
fi

echo "计划重建 ${#link_pairs[@]} 个软链接 → $SKILLS_DIR"
[[ $CHECK_ONLY -eq 1 ]] && { printf '%s\n' "${link_pairs[@]:-}"; exit 0; }

mkdir -p "$SKILLS_DIR"
ok=0; bad=0
for pair in "${link_pairs[@]:-}"; do
  [[ -z "$pair" ]] && continue
  name="${pair%%:*}"; target="${pair#*:}"
  cur="$SKILLS_DIR/$name"
  # 已有真实目录则不动（用户手改过的优先）
  if [[ -e "$cur" && ! -L "$cur" ]]; then log "跳过真实目录 $name"; continue; fi
  ln -sfn "$target" "$cur"
  if [[ -e "$cur/SKILL.md" ]]; then ok=$((ok+1)); else bad=$((bad+1)); log "坏链 $name → $target"; fi
done

echo "已重建 $ok 个，异常 $bad 个"
echo "校验：find ~/.agents/skills -maxdepth 1 -type l ! -exec test -e {}/SKILL.md \; -print"
