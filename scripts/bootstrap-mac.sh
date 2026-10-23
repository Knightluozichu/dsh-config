#!/usr/bin/env bash
# 在 macOS 上一键落位 dsh-config。
# 用法：git clone <repo> ~/dsh-config && bash ~/dsh-config/scripts/bootstrap-mac.sh
# 幂等：重复跑只会覆盖配置、重建链接，不会删你本机的 session。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${HOME}"
log()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*"; }

# ---------- 0. 前置 ----------
log "0/7 检查前置命令"
need_brew=0
for c in git rg; do command -v "$c" >/dev/null 2>&1 || need_brew=1; done
if [[ $need_brew -eq 1 ]]; then
  if command -v brew >/dev/null 2>&1; then
    warn "安装 git / ripgrep"; brew install git ripgrep
  else
    warn "未安装 Homebrew，请先装 brew 再重跑（https://brew.sh）"; exit 1
  fi
fi

# ---------- 1. dsh 配置 ----------
log "1/7 落位 ~/.dsh 配置（不碰 sessions/storages/profiles）"
mkdir -p "$HOME_DIR/.dsh"
for f in settings.yaml AGENTS.md; do
  [[ -f "$REPO/dsh/$f" ]] || { warn "缺 dsh/$f"; continue; }
  if [[ -f "$HOME_DIR/.dsh/$f" ]]; then
    cp -n "$HOME_DIR/.dsh/$f" "$HOME_DIR/.dsh/$f.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  fi
  cp "$REPO/dsh/$f" "$HOME_DIR/.dsh/$f"
done

# ---------- 2. agents skills ----------
log "2/7 落位 ~/.agents/skills（真实目录，链接见第 4 步）"
mkdir -p "$HOME_DIR/.agents/skills"
if [[ -d "$REPO/agents/skills" ]]; then
  for d in "$REPO"/agents/skills/*/; do
    name="$(basename "$d")"
    target="$HOME_DIR/.agents/skills/$name"
    [[ -L "$target" ]] && rm -f "$target"          # 链接位让给 relink.sh
    rm -rf "$target"; cp -R "$d" "$target"
  done
fi
[[ -d "$REPO/agents/skills-disabled" ]] && rm -rf "$HOME_DIR/.agents/skills-disabled" \
  && cp -R "$REPO/agents/skills-disabled" "$HOME_DIR/.agents/skills-disabled"
[[ -f "$REPO/agents/skill-lock.json" ]] && cp "$REPO/agents/skill-lock.json" "$HOME_DIR/.agents/.skill-lock.json"

# ---------- 3. 插件源（能 clone 的都不复制）----------
log "3/7 准备插件源"
if [[ ! -d "$HOME_DIR/.codex/plugins/cache/ponytail" ]]; then
  warn "ponytail 插件未安装 → 稍后 relink.sh 会跳过 6 个 skill"
  warn "  安装后重跑本脚本，或手动指定 PONYTAIL_ROOT=<路径> bash scripts/relink.sh"
fi
if [[ ! -d "$HOME_DIR/.understand-anything" ]]; then
  warn "understand-anything 未安装 → 稍后 relink.sh 会跳过 9 个 skill"
fi

# ---------- 4. 重建链接 ----------
log "4/7 重建 junction 对应的软链接"
bash "$REPO/scripts/relink.sh"

# ---------- 5. CLI ----------
log "5/7 安装 CLI（已存在则跳过）"
if command -v npm >/dev/null 2>&1; then
  command -v codegraph >/dev/null 2>&1 || npm i -g @colbymchenry/codegraph
  warn "按需手动补：@anthropic-ai/claude-code、@deepseek-ai/dsh、@lark-project/meegle、@qoder-ai/qmind-cli、@mermaid-js/mermaid-cli"
else
  warn "无 npm，跳过 CLI 安装"
fi

# ---------- 6. claude 配置 ----------
log "6/7 落位 ~/.claude 配置并渲染 settings.json"
mkdir -p "$HOME_DIR/.claude/commands"
for f in CLAUDE.md statusline-command.sh; do
  [[ -f "$REPO/claude/$f" ]] && cp "$REPO/claude/$f" "$HOME_DIR/.claude/$f"
done
[[ -f "$HOME_DIR/.claude/statusline-command.sh" ]] && chmod +x "$HOME_DIR/.claude/statusline-command.sh"
cp -R "$REPO"/claude/commands/* "$HOME_DIR/.claude/commands/" 2>/dev/null || true

if [[ -f "$REPO/claude/settings.template.json" ]]; then
  : "${ANTHROPIC_BASE_URL:=http://localhost:20128/v1}"
  : "${ANTHROPIC_AUTH_TOKEN:=__FILL_ME__}"
  if [[ "$ANTHROPIC_AUTH_TOKEN" == "__FILL_ME__" ]]; then
    warn "ANTHROPIC_AUTH_TOKEN 未设置，settings.json 里会是占位符，请手动填"
  fi
  sed -e "s|\${ANTHROPIC_BASE_URL}|$ANTHROPIC_BASE_URL|g" \
      -e "s|\${ANTHROPIC_AUTH_TOKEN}|$ANTHROPIC_AUTH_TOKEN|g" \
      "$REPO/claude/settings.template.json" > "$HOME_DIR/.claude/settings.json"
fi

# ---------- 7. 自检 ----------
log "7/7 自检"
printf '  skills 目录数 : %s\n' "$(find "$HOME_DIR/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
printf '  软链接数     : %s\n' "$(find "$HOME_DIR/.agents/skills" -mindepth 1 -maxdepth 1 -type l | wc -l | tr -d ' ')"
printf '  悬空链接     : %s\n' "$(find "$HOME_DIR/.agents/skills" -mindepth 1 -maxdepth 1 -type l ! -exec test -e {}/SKILL.md \; -print | wc -l | tr -d ' ')"
printf '  .dsh 文本配置 : %s 个文件\n' "$(ls -1 "$HOME_DIR/.dsh" | grep -E '\.(yaml|md)$' | wc -l | tr -d ' ')"

echo
log "还需你手工完成（脚本无法代做）"
cat <<'EOF'
  1) 填 API key：~/.dsh/.credentials.yaml（DEEPSEEK_API_KEY / FUYAO_API_KEY）
  2) Gerrit 的 SSH key：ssh-keygen -t ed25519，公钥上传到 ci.x-peng.com:29418
  3) 若用 9remote / 9router：在 ~/.claude/settings.json 补回 localhost:2208 的 notify hook
  4) 打开 DSH，验证全局 AGENTS.md 生效（问它「本次改动边界有哪些」）
EOF
