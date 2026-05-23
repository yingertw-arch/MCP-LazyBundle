# AI Agent shared CLI auth helper
# This script guides local browser-based login for GitHub CLI and Firebase CLI.
# It never asks for, writes, or commits manual tokens.

$ErrorActionPreference = "Continue"

function Test-CommandExists {
  param([Parameter(Mandatory = $true)][string]$Name)
  $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-OptionalLogin {
  param(
    [Parameter(Mandatory = $true)][string]$ServiceName,
    [Parameter(Mandatory = $true)][scriptblock]$LoginCommand
  )
  $answer = Read-Host "$ServiceName 尚未登入或狀態異常。是否現在開啟瀏覽器登入？(Y/N)"
  if ($answer -match '^(Y|y|是|好)$') {
    & $LoginCommand
  } else {
    Write-Host "略過 $ServiceName 登入。需要時可稍後再執行本腳本。"
  }
}

Write-Host "== AI Agent 共用登入檢查 =="
Write-Host "原則：使用官方 CLI 瀏覽器登入；不建立、不貼上、不保存手動 token 到專案。"
Write-Host ""

Write-Host "== MCP 環境變數檢查 =="
if ($env:GITHUB_PAT_TOKEN) {
  Write-Host "GITHUB_PAT_TOKEN: 已設定（不顯示內容）"
} else {
  Write-Warning "GITHUB_PAT_TOKEN: 未設定。GitHub remote MCP 可能無法驗證；請只在本機環境變數或 OS 憑證庫設定，不要寫進 repo。"
}
if ($env:OBSIDIAN_API_KEY) {
  Write-Host "OBSIDIAN_API_KEY: 已設定（不顯示內容）"
} else {
  Write-Warning "OBSIDIAN_API_KEY: 未設定。Obsidian MCP 可能無法驗證；請只在本機環境變數設定，不要寫進 repo。"
}
Write-Host ""

Write-Host "== GitHub CLI =="
if (!(Test-CommandExists "gh")) {
  Write-Warning "找不到 gh。請先安裝 GitHub CLI：https://cli.github.com/"
} else {
  $env:GITHUB_TOKEN = ""
  gh auth status
  if ($LASTEXITCODE -ne 0) {
    Invoke-OptionalLogin -ServiceName "GitHub CLI" -LoginCommand {
      $env:GITHUB_TOKEN = ""
      gh auth login --web --git-protocol https
      gh auth status
    }
  } else {
    Write-Host "GitHub CLI 已登入。"
  }
}

Write-Host ""
Write-Host "== Firebase CLI =="
if (!(Test-CommandExists "firebase")) {
  Write-Warning "找不到 firebase。請先執行：npm install -g firebase-tools"
} else {
  cmd /c firebase projects:list
  if ($LASTEXITCODE -ne 0) {
    Invoke-OptionalLogin -ServiceName "Firebase CLI" -LoginCommand {
      cmd /c firebase login
      cmd /c firebase projects:list
    }
  } else {
    Write-Host "Firebase CLI 已登入。"
  }
}

Write-Host ""
Write-Host "完成。之後同一台電腦上的 Codex、OpenCode 與其他 AI Agent 可共用這些 CLI 登入狀態。"
