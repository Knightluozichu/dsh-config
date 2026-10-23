# dsh-config

Windows 与 macOS 之间同步 DSH / Claude 的**可移植配置**。原则：**能 clone 的都不复制，能重装的都不搬运。**

## 为什么不是直接同步 `~/.dsh`

| 不搬 | 体积 | 原因 |
| --- | --- | --- |
| `profiles/` | ~350 MB | 依赖 node_modules，由 DSH 安装器重建 |
| `sessions/`、`storages/` | ~100 MB | 内含 `E:\Code\...` 绝对路径与会话历史，换机即失效 |
| `.credentials.yaml` | 123 B | 明文 API key，绝不入库 |
| `~/.understand-anything`、ponytail 插件 | ~600 MB | 独立仓/插件缓存，目标机重新安装 |

本仓只收 **5.2 MB 文本**。

## 结构

| 路径 | 内容 | 目标机落点 |
| --- | --- | --- |
| `dsh/settings.yaml` | DSH 提供方、模型、权限预设 | `~/.dsh/settings.yaml` |
| `dsh/AGENTS.md` | 全局工作流（六段 + 路由 + 硬判据） | `~/.dsh/AGENTS.md` |
| `claude/CLAUDE.md` | Claude Code 全局契约 | `~/.claude/CLAUDE.md` |
| `claude/settings.template.json` | 脱敏后的 settings，含 `${VAR}` 占位 | 渲染为 `~/.claude/settings.json` |
| `claude/commands/` | 斜杠命令 | `~/.claude/commands/` |
| `claude/statusline-command.sh` | 状态栏脚本 | `~/.claude/` |
| `agents/skills/` | 55 个**真实目录** skill | `~/.agents/skills/` |
| `agents/skills-disabled/` | 移出但可回滚的 skill | `~/.agents/skills-disabled/` |
| `agents/skill-lock.json` | skill 来源与版本锁 | `~/.agents/.skill-lock.json` |
| `scripts/export.ps1` | Windows 侧导出并 commit | — |
| `scripts/bootstrap-mac.sh` | macOS 侧一键落位 | — |
| `scripts/relink.sh` | 重建插件软链接 | — |

## 日常用法

```bash
# ── Windows 改完配置后，推送 ──
pwsh -File scripts/export.ps1
git commit -am "sync: win <日期>" && git push

# ── mac 上拉取 ──
git pull && bash scripts/bootstrap-mac.sh

# ── mac 上改完，反向同步 ──
git commit -am "sync: mac <日期>" && git push    # 手工把改动落回对应子目录
```

## 四个必须知道的坑

| 坑 | 表现 | 本仓的对策 |
| --- | --- | --- |
| **junction 不是文件** | `~/.agents/skills/ponytail` 在 Windows 是目录重解析点，git 里存不下 | 只提交 55 个真实目录；15 个链接由 `relink.sh` 用 `ln -s` 重建 |
| **settings.json 深绑 Windows** | `CLAUDE_CODE_GIT_BASH_PATH`、`C:/Users/XPENG/.git-ai/bin/git-ai.exe`、`localhost:2208` notify hook | 模板剔除这些块；需要时按下方「可选补回」手工加 |
| **CRLF** | `#!/bin/bash\r` → `bad interpreter` | `.gitattributes` 强制 `*.sh` 为 `eol=lf` |
| **BOM** | YAML/JSON 带 BOM 解析失败 | 源文件已确认无 BOM，导出时保持原字节 |

> `.ps1` 例外：**必须存为 UTF-8 with BOM**。Windows PowerShell 5.1 会把无 BOM 的 UTF-8 当 GBK 读，中文字符会吞掉换行、破坏语法（本仓 `export.ps1` 已带 BOM）。`.sh` 则必须无 BOM。

### 可选补回（Windows 专属 hook）

```json
"PostToolUse": [{ "matcher": "*", "hooks": [
  { "type": "command", "command": "<HOME>/.git-ai/bin/git-ai checkpoint claude --hook-input stdin" }]}]
```
9remote 通知 hook（`localhost:2208/api/notify`）同理，仅当目标机也跑 9router 时补。

## 目标机自检

```bash
find ~/.agents/skills -mindepth 1 -maxdepth 1 -type d | wc -l          # 期望 55
find ~/.agents/skills -mindepth 1 -maxdepth 1 -type l | wc -l          # 期望 15
find ~/.agents/skills -maxdepth 1 -type l ! -exec test -e {}/SKILL.md \; -print   # 期望空
codegraph --version && rg --version
```

## 脚本无法代做的四件事

1. `~/.dsh/.credentials.yaml` 里的 `DEEPSEEK_API_KEY` / `FUYAO_API_KEY`（安全通道手动填）
2. Gerrit 的 SSH key（`ci.x-peng.com:29418`）
3. 9remote / 9router 等本机服务
4. Unity 工程路径（`workspace.json` 里的 `E:\Code\...` 一律不搬）
