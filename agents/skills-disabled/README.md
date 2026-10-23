# 已停用的 skill

从 `C:\Users\XPENG\.agents\skills` 移出，保留在这里以便回滚。移出原因：它们绑定的是本机不存在的生态。

| skill | 原因 |
| --- | --- |
| `setup-pre-commit` | 依赖 npm / husky / lint-staged / prettier，本仓是 Unity 工程，没有 package.json |
| `migrate-to-shoehorn` | 只处理 TypeScript 测试里的 `as` 断言与 `@total-typescript/shoehorn` |
| `scaffold-exercises` | 依赖 `pnpm ai-hero-cli internal lint` 的课程练习目录规范 |
| `git-guardrails-claude-code` | 只对 Claude Code 的 `settings.json` + `PreToolUse` hook 生效，DSH 不读该配置 |

回滚方式：

```powershell
Move-Item "C:\Users\XPENG\.agents\skills-disabled\<name>" "C:\Users\XPENG\.agents\skills\<name>"
```

来源仓库：`C:\Users\XPENG\.agents\sources\mattpocock-skills`（`git pull` 可取回最新版本）。
