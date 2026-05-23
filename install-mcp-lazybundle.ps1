# Codex MCP LazyBundle installer
# Adds MCP server blocks to $HOME\.codex\config.toml. No secrets are written.

$ErrorActionPreference = "Stop"

$bundleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $HOME ".codex\config.toml"
$snippetPath = Join-Path $bundleRoot "mcp-servers\all.codex.toml"

if (!(Test-Path $snippetPath)) {
  throw "Missing snippet: $snippetPath"
}
if (!(Test-Path $configPath)) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configPath) | Out-Null
  New-Item -ItemType File -Force -Path $configPath | Out-Null
}

$config = Get-Content -Raw -Encoding UTF8 $configPath
$snippet = Get-Content -Raw -Encoding UTF8 $snippetPath

$backupPath = "$configPath.bak-lazybundle-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -LiteralPath $configPath -Destination $backupPath -Force

foreach ($server in @('github', 'firebase', 'obsidian', 'notebooklm')) {
  $pattern = "(?m)^\[mcp_servers\.$server\]"
  if ($config -notmatch $pattern) {
    $block = ($snippet -split "(?m)(?=^\[mcp_servers\.)" | Where-Object { $_ -match "^\[mcp_servers\.$server\]" }) -join "`r`n"
    $append = "`r`n# Added by MCP-LazyBundle on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n$block"
    Add-Content -Encoding UTF8 -LiteralPath $configPath -Value $append
    Write-Host "Added $server MCP to $configPath"
  } else {
    Write-Host "$server MCP already exists in $configPath"
  }
}

Write-Host "Backup created: $backupPath"
Write-Host "Next: restart/reload Codex. NotebookLM needs setup_auth once; Firebase uses firebase login; GitHub/Obsidian read local environment variables only."
