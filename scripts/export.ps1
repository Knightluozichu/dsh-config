# 从 Windows 本机导出 DSH / Claude 配置到本仓。
# 用法：powershell -File scripts\export.ps1 [-DryRun]
# 注意：本文件必须存为 UTF-8 with BOM，否则 Windows PowerShell 5.1 会按 GBK 读，中文字符会吞掉换行、破坏语法。
# 只导出「可移植的文本」：不碰 .credentials*、sessions、profiles、storages、第三方插件源码。

[CmdletBinding()]
param([switch]$DryRun, [string]$RepoRoot)

$ErrorActionPreference = 'Stop'
$U = $env:USERPROFILE

# $PSScriptRoot 在参数默认值阶段尚未可用，必须在脚本体内解析
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }
$RepoRoot = $RepoRoot.TrimEnd('\')

if (-not (Test-Path (Join-Path $RepoRoot '.gitattributes'))) {
  throw "RepoRoot 不像 dsh-config 仓：$RepoRoot"
}

function Copy-Text([string]$From, [string]$To) {
  if (-not (Test-Path $From)) { Write-Warning "跳过（不存在）: $From"; return }
  if ($DryRun) { Write-Host "would copy $From -> $To"; return }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $To) | Out-Null
  Copy-Item -LiteralPath $From -Destination $To -Force
}

# ---- 1. dsh 配置 ----
Copy-Text "$U\.dsh\settings.yaml" (Join-Path $RepoRoot 'dsh\settings.yaml')
Copy-Text "$U\.dsh\AGENTS.md"     (Join-Path $RepoRoot 'dsh\AGENTS.md')

# ---- 2. claude 配置（settings.json 含 token，只导出模板）----
Copy-Text "$U\.claude\CLAUDE.md"             (Join-Path $RepoRoot 'claude\CLAUDE.md')
Copy-Text "$U\.claude\statusline-command.sh" (Join-Path $RepoRoot 'claude\statusline-command.sh')
if (Test-Path "$U\.claude\commands") {
  if ($DryRun) { Write-Host "would copy commands\*" }
  else {
    $cmdDst = Join-Path $RepoRoot 'claude\commands'
    New-Item -ItemType Directory -Force -Path $cmdDst | Out-Null
    Copy-Item "$U\.claude\commands\*" $cmdDst -Recurse -Force
  }
}
Write-Host "提示：settings.json 不导出（含 ANTHROPIC_AUTH_TOKEN）；通用项改动请手动同步 claude\settings.template.json"

# ---- 3. agents skills：只拷真实目录，跳过 junction ----
$skillsSrc = "$U\.agents\skills"
$skillsDst = Join-Path $RepoRoot 'agents\skills'
$links = @(Get-ChildItem $skillsSrc -Force | Where-Object { $_.LinkType })
$real  = @(Get-ChildItem $skillsSrc -Force | Where-Object { -not $_.LinkType -and $_.PSIsContainer })

Write-Host ("真实 skill 目录 {0} 个，junction {1} 个（跳过，由 scripts/relink.sh 在目标机重建）" -f $real.Count, $links.Count)
if (-not $DryRun) {
  New-Item -ItemType Directory -Force -Path $skillsDst | Out-Null
  foreach ($d in $real) {
    # 目标已存在时 Copy-Item 会把源目录塞进目标里（X/X 嵌套），必须先删后拷
    $dst = Join-Path $skillsDst $d.Name
    if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
    Copy-Item -LiteralPath $d.FullName -Destination $dst -Recurse -Force
  }
  # 同步删除仓库里已不存在的 skill
  Get-ChildItem $skillsDst -Directory -Force | Where-Object { $_.Name -notin $real.Name } | ForEach-Object {
    Write-Host "移除已卸载 skill: $($_.Name)"
    Remove-Item -LiteralPath $_.FullName -Recurse -Force
  }
}

if (Test-Path "$U\.agents\skills-disabled") {
  if ($DryRun) { Write-Host "would copy skills-disabled" }
  else {
    $disDst = Join-Path $RepoRoot 'agents\skills-disabled'
    if (Test-Path -LiteralPath $disDst) { Remove-Item -LiteralPath $disDst -Recurse -Force }
    Copy-Item -LiteralPath "$U\.agents\skills-disabled" -Destination $disDst -Recurse -Force
  }
}
Copy-Text "$U\.agents\.skill-lock.json" (Join-Path $RepoRoot 'agents\skill-lock.json')

# ---- 4. 自检 ----
if (-not $DryRun) {
  $residual = @(Get-ChildItem $skillsDst -Force | Where-Object { $_.LinkType })
  if ($residual.Count -gt 0) { throw "仓库里混入了 junction：$($residual.Name -join ', ')" }

  $loose = @(Get-ChildItem $skillsDst -Force | Where-Object { -not $_.PSIsContainer })
  if ($loose.Count -gt 0) { throw "skills 根目录出现散文件（目录被摊平的征兆）：$($loose.Name -join ', ')" }

  $dirs = @(Get-ChildItem $skillsDst -Directory -Force)
  if ($dirs.Count -ne $real.Count) { throw "skill 目录数不一致（源 $($real.Count) / 仓 $($dirs.Count)）" }

  # 逐目录比对文件数：同时抓「摊平」和「X/X 嵌套」两类事故
  foreach ($d in $dirs) {
    $repoCount = @(Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Force).Count
    $srcCount  = @(Get-ChildItem -LiteralPath (Join-Path $skillsSrc $d.Name) -Recurse -File -Force).Count
    if ($repoCount -ne $srcCount) {
      throw ("{0} 文件数不一致（源 {1} / 仓 {2}）——检查是否摊平或嵌套" -f $d.Name, $srcCount, $repoCount)
    }
  }
  Write-Host ("自检通过：{0} 个 skill，无 junction、无散文件、文件数逐个一致" -f $dirs.Count)

  Push-Location $RepoRoot
  try {
    git add -A
    git status --short
    Write-Host "`n完成。确认无误后：git commit -m 'sync: <机器名> <日期>'"
  } finally { Pop-Location }
}
