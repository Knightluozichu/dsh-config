# 用户全局约定

适用于所有仓库。优先级：系统提示 > 本文件 > 仓库 `CLAUDE.md` / `AGENTS.md` > skill。本文件只放工作流脊柱、路由与硬判据；流程细节在 skill，项目契约在仓库文件。

## 工作流：六段，每段有退出判据

| 段 | 做什么 | 退出判据（做不到就不进下一段） | 用哪个 skill |
| --- | --- | --- | --- |
| 0 定位 | 读仓库规则、`git status`、分清既有脏改动属于谁 | 说得出改动边界和「不碰的文件」 | — |
| 1 对齐 | 需求有分叉就先盘问，不猜 | 验收项写成可执行判定 | `grilling` / `grill-with-docs` |
| 2 计划 | 列出改动面、风险、验证命令 | 超过一个文件或跨模块才写计划 | `codebase-design` |
| 3 执行 | 最小完整改动，先红后绿 | 每个验收项都有对应改动 | `ponytail` / `tdd` |
| 4 验证 | 每个验收项跑一条命令 | 贴得出输出；「应该没问题」不算 | `diagnosing-bugs`（红了才用） |
| 5 交付 | 按仓库 git 约定写提交，不自动 push | 工作区回到约定的状态 | `code-review` / `gerrit-change` |
| 6 复盘 | 只改环境不改代码 | 产出一条可执行的检查或导航指针 | `retro` |

小改动走 0→3→4→5，不必每段留痕；但第 4 段不能跳。

## 路由：按你听到的话选入口

| 听到 | 先做 |
| --- | --- |
| 需求模糊、「帮我做个 X」 | 加载 `grilling` 盘问 |
| 报错、坏了、变慢 | 加载 `diagnosing-bugs` |
| 要改代码 | 加载 `ponytail`，再按改动大小决定是否 `tdd` |
| 审改动、送审前自检 | 加载 `code-review` |
| 提交、送审 | 加载 `gerrit-change`，消息格式以仓库文档为准 |
| 一个 session 装不下的大工程 | `to-spec` → `to-tickets` → `implement` |
| 代码库越改越难懂 | `improve-codebase-architecture` |
| 「先记下来回头做」 | 用仓库自带的 issue 约定；没有就写 `issues/open/` |

表里只放高频且会分叉的入口；其余靠 skill 描述匹配，不在这里枚举。

## 三条硬判据

1. **证据先于结论。** 说「改好了」必须附命令与输出；没有输出的完成按未完成处理。
2. **验收项由需求定，不由实现定。** 不改测试、不改评分、不放宽断言来换取通过。
3. **不确定归用户。** 需求取舍、破坏性操作、索引与发布这类外部动作，先问再做。

## 上下文纪律

- 本文件常驻，每条规则要能说出它挡掉了哪个具体错误；说不出来就删。
- 项目细节写进仓库 `CLAUDE.md`，不往上搬；这里只放跨仓库不变的东西。
- 全量读之前先判断能否只读一段；能命名符号时先走 CodeGraph。

# CodeGraph 使用约定（用户全局）

适用于所有仓库。仅在项目根存在 `.codegraph/` 时启用；不要在未索引的项目里反复调用 codegraph 工具。

## 检索顺序

- 需要定位符号、理解调用流、或读取能够命名的代码时，**先调用 `codegraph_explore`**，再考虑 grep/glob/read。
- 不要用 grep/glob 先"找文件"再读：索引已经做完这步，一次 explore 顶几十次往返。
- `codegraph_explore` 返回的源码是逐行、与磁盘一致的原文，视为已 Read，可以直接据此编辑。
- 不要用 grep 复核 explore 的结果，它来自完整 AST 解析。

## 生命周期

- 每个项目第一次涉及检索时，用 `codegraph_status` 确认一次是否已初始化；确认后本轮不再重复查询。
- 改动源码后运行 `codegraph_sync`，让后续查询反映新代码。
- 索引报告未初始化时，**不要自行 `codegraph_init`**——索引是用户的决定，先问。
- 索引提示 `reindexRecommended`（提取版本落后）或 `pendingChanges` 积压时，只向用户报告，不擅自全量重建。

## 边界

- CodeGraph 不替代看代码：涉及配置、资源、shader、Editor 工具或索引未覆盖的语言时，照常用 read/grep。
- explore 返回的"blast radius"是改动影响面提示，不是修改许可；跨模块改动前仍要按仓库自己的协作规则确认。

# Ponytail 模式（改代码时启用）

适用于所有仓库。只约束写代码；纯查询、解释、文档类任务不必启用。

## 何时启用

- 只要要改代码——写、修 bug、重构、评审、选依赖——动手前先调用 `skill` 加载 `ponytail`。
- 加载后本会话持续生效，默认 `full` 档；用户说 `/ponytail lite` 或 `/ponytail ultra` 换档，说 "stop ponytail" / "normal mode" 退出。
- 相关 skill：`ponytail-review`（审改动）、`ponytail-audit`（整仓体检）、`ponytail-debt`（列出 `shortcut:` 欠账）、`ponytail-help`（速查）。

## 已接好的路径

- 技能入口：`~/.agents/skills/ponytail`、`-audit`、`-debt`、`-gain`、`-help`、`-review`，均为 junction。
- 指向：`~/.codex/plugins/cache/ponytail/ponytail/<version>/skills/<name>`。
- 插件升级会换版本目录，junction 随之失效；此时**重建 junction 指向新版本**，不要复制文件、不要改缓存内容。

## 与 CodeGraph 的分工

- CodeGraph 管"怎么找代码"，ponytail 管"改多少代码"，两者并行，不互相替代。
- 先 explore 定位影响面，再按 ponytail 的最小完整改动落地；改完照常 `codegraph_sync`。
