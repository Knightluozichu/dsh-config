#!/usr/bin/env bash
# 在目标机（macOS / Linux）重建 ~/.agents/skills 下的插件软链接。
# Windows 上的 junction 无法随 git 复制，必须在此重建。
# 用法：bash scripts/relink.sh [--check]
set -euo pipefail

# macOS 自带 bash 3.2：变量必须显式 ${} 定界，否则紧跟的中文/全角标点会被当成变量名的一部分
CHECK_ONLY=0
if [ "${1:-}" = "--check" ]; then
  CHECK_ONLY=1
fi

SKILLS_DIR="${HOME}/.agents/skills"
PONYTAIL_ROOT_DEFAULT="${HOME}/.codex/plugins/cache/ponytail"
UNDERSTAND_ROOT_DEFAULT="${HOME}/.understand-anything/repo/understand-anything-plugin/skills"

# 仅用于在 Windows 上验证建链逻辑（FORCE_LINUX=1），日常不要设置
PONYTAIL_ROOT="${PONYTAIL_ROOT:-${PONYTAIL_ROOT_DEFAULT}}"
UNDERSTAND_ROOT="${UNDERSTAND_ROOT:-${UNDERSTAND_ROOT_DEFAULT}}"

log() { printf '  %s\n' "${*}"; }

# Windows 侧同步走 export.ps1；本脚本在 Windows 只做存在性检查，绝不覆盖 junction
IS_WINDOWS=0
case "$(uname -s 2>/dev/null || echo unknown)" in
  MSYS*|MINGW*|CYGWIN*)
    IS_WINDOWS=1
    log "提示：检测到 Windows 环境。此处 skills 是 junction，脚本只检查不覆盖；同步请用 scripts/export.ps1" ;;
esac

# 仅用于在 Windows 上验证建链逻辑（FORCE_LINUX=1），日常不要设置
if [ "${FORCE_LINUX:-0}" = "1" ]; then
  IS_WINDOWS=0
fi

# 实际结构：.../ponytail/<version>/.openclaw/skills，深度不固定
find_ponytail_skills() {
  local base="${PONYTAIL_ROOT}"
  if [ ! -d "${base}" ]; then
    return 1
  fi
  local cand
  cand="$(find "${base}" -maxdepth 5 -type d -name skills 2>/dev/null | sort -V | tail -n 1)"
  if [ -n "${cand}" ]; then
    printf '%s' "${cand}"
  else
    return 1
  fi
}

PONYTAIL_SKILLS=""
PONYTAIL_SKILLS="$(find_ponytail_skills || true)"

link_pairs=""
add_pair() {
  # 追加 "名字:真实路径" 到列表（换行分隔，避免 bash 3.2 数组下标语法差异）
  if [ -z "${link_pairs}" ]; then
    link_pairs="$1:$2"
  else
    link_pairs="${link_pairs}
$1:$2"
  fi
}

# 插件源没装时，如实区分「本机已有真实目录（沿用）」和「真的没有」
report_no_source() {
  local label="${1}"
  local root="${2}"
  local total="${3}"
  shift 3
  local have=0
  local n
  for n in "$@"; do
    if [ -e "${SKILLS_DIR}/${n}" ] && [ ! -L "${SKILLS_DIR}/${n}" ]; then
      have=$((have + 1))
    fi
  done
  if [ "${have}" -eq "${total}" ]; then
    log "${label} 插件源未装，沿用本机已有真实目录 ${have}/${total} 个（无需处理）"
  elif [ "${have}" -gt 0 ]; then
    log "未找到 ${label} 插件源 ${root}（本机已有真实目录 ${have}/${total} 个，缺 $((total - have)) 个）"
  else
    log "未找到 ${label} 插件源: ${root}（跳过 ${total} 个 skill）"
  fi
}

PONYTAIL_NAMES="ponytail ponytail-audit ponytail-debt ponytail-gain ponytail-help ponytail-review"
UNDERSTAND_NAMES="understand understand-chat understand-dashboard understand-diff understand-domain understand-explain understand-figma understand-knowledge understand-onboard"

if [ -n "${PONYTAIL_SKILLS}" ]; then
  for n in ${PONYTAIL_NAMES}; do
    if [ -d "${PONYTAIL_SKILLS}/${n}" ]; then
      add_pair "${n}" "${PONYTAIL_SKILLS}/${n}"
    fi
  done
else
  report_no_source ponytail "${PONYTAIL_ROOT}" 6 ${PONYTAIL_NAMES}
fi

if [ -d "${UNDERSTAND_ROOT}" ]; then
  for n in ${UNDERSTAND_NAMES}; do
    if [ -d "${UNDERSTAND_ROOT}/${n}" ]; then
      add_pair "${n}" "${UNDERSTAND_ROOT}/${n}"
    fi
  done
else
  report_no_source understand-anything "${UNDERSTAND_ROOT}" 9 ${UNDERSTAND_NAMES}
fi

count=0
if [ -n "${link_pairs}" ]; then
  count="$(printf '%s\n' "${link_pairs}" | grep -c .)"
fi

echo "计划重建 ${count} 个软链接 -> ${SKILLS_DIR}"
if [ "${count}" -eq 0 ]; then
  echo "（没有需要新建的链接：要么插件源没装、要么本机已经是真实目录。悬空链接检查见 bootstrap 末步 7/7）"
fi

if [ "${CHECK_ONLY}" -eq 1 ]; then
  if [ -n "${link_pairs}" ]; then
    printf '%s\n' "${link_pairs}"
  fi
  exit 0
fi

mkdir -p "${SKILLS_DIR}"
ok=0
bad=0
while IFS= read -r pair; do
  if [ -z "${pair}" ]; then
    continue
  fi
  name="${pair%%:*}"
  target="${pair#*:}"
  cur="${SKILLS_DIR}/${name}"
  # Windows：只核对，不改动（junction 在 MSYS 里表现为 -L，硬写会破坏链接）
  if [ "${IS_WINDOWS}" -eq 1 ]; then
    if [ -e "${cur}/SKILL.md" ]; then
      log "已存在 ${name}（junction，不动）"
      ok=$((ok + 1))
    else
      bad=$((bad + 1))
      log "缺失 ${name}（Windows 请用 scripts/export.ps1 从源机同步）"
    fi
    continue
  fi
  # 已存在就绝不覆盖：真实目录、普通文件
  if [ ! -L "${cur}" ] && { [ -e "${cur}" ] || [ -d "${cur}" ]; }; then
    log "跳过已存在 ${name}"
    continue
  fi
  ln -sfn "${target}" "${cur}"
  if [ -e "${cur}/SKILL.md" ]; then
    ok=$((ok + 1))
  else
    bad=$((bad + 1))
    log "坏链 ${name} -> ${target}"
  fi
done <<EOF
${link_pairs}
EOF

if [ "${IS_WINDOWS}" -eq 1 ]; then
  echo "已核对 ${ok} 个，缺失 ${bad} 个"
else
  echo "已重建 ${ok} 个，异常 ${bad} 个"
fi
echo "校验：find ~/.agents/skills -maxdepth 1 -type l ! -exec test -e {}/SKILL.md \\; -print"
