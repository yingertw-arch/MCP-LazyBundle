# Cross-agent MCP LazyBundle installer
# Installs local MCP configuration for Codex, OpenCode, Claude Desktop, and a reusable project mcp.json.
# No secrets, API keys, PATs, or tokens are written.

param(
  [string[]]$Targets = @("Codex", "OpenCode", "ClaudeDesktop", "ProjectMcpJson"),
  [string]$ProjectPath = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$bundleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupStamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Ensure-ParentDir {
  param([Parameter(Mandatory = $true)][string]$Path)
  $parent = Split-Path -Parent $Path
  if ($parent -and !(Test-Path $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
}

function Backup-FileIfExists {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (Test-Path $Path) {
    $backup = "$Path.bak-lazybundle-$backupStamp"
    Copy-Item -LiteralPath $Path -Destination $backup -Force
    Write-Host "Backup created: $backup"
  }
}

function Read-JsonObjectOrEmpty {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (!(Test-Path $Path) -or ((Get-Item $Path).Length -eq 0)) {
    return [ordered]@{}
  }
  try {
    $jsonObject = Get-Content -Raw -Encoding UTF8 $Path | ConvertFrom-Json
    return ConvertTo-Hashtable $jsonObject
  } catch {
    throw "Cannot parse JSON config: $Path. Please fix it first. $($_.Exception.Message)"
  }
}

function ConvertTo-Hashtable {
  param($InputObject)
  if ($null -eq $InputObject) { return $null }
  if ($InputObject -is [System.Collections.IDictionary]) {
    $hash = [ordered]@{}
    foreach ($key in $InputObject.Keys) {
      $hash[$key] = ConvertTo-Hashtable $InputObject[$key]
    }
    return $hash
  }
  if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
    $array = @()
    foreach ($item in $InputObject) {
      $array += ConvertTo-Hashtable $item
    }
    return $array
  }
  if ($InputObject.PSObject.Properties.Count -gt 0 -and $InputObject.GetType().Name -eq 'PSCustomObject') {
    $hash = [ordered]@{}
    foreach ($prop in $InputObject.PSObject.Properties) {
      $hash[$prop.Name] = ConvertTo-Hashtable $prop.Value
    }
    return $hash
  }
  return $InputObject
}

function Write-JsonObject {
  param(
    [Parameter(Mandatory = $true)]$Object,
    [Parameter(Mandatory = $true)][string]$Path
  )
  Ensure-ParentDir -Path $Path
  $json = $Object | ConvertTo-Json -Depth 20
  Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

function Install-Codex {
  $configPath = Join-Path $HOME ".codex\config.toml"
  $snippetPath = Join-Path $bundleRoot "mcp-servers\all.codex.toml"
  if (!(Test-Path $snippetPath)) { throw "Missing snippet: $snippetPath" }

  Ensure-ParentDir -Path $configPath
  if (!(Test-Path $configPath)) { New-Item -ItemType File -Force -Path $configPath | Out-Null }

  $config = Get-Content -Raw -Encoding UTF8 $configPath
  Backup-FileIfExists -Path $configPath

  $snippet = Get-Content -Raw -Encoding UTF8 $snippetPath
  foreach ($server in @('github', 'firebase', 'obsidian', 'notebooklm')) {
    $pattern = "(?m)^\[mcp_servers\.$server\]"
    if ($config -notmatch $pattern) {
      $block = ($snippet -split "(?m)(?=^\[mcp_servers\.)" | Where-Object { $_ -match "^\[mcp_servers\.$server\]" }) -join "`r`n"
      Add-Content -Encoding UTF8 -LiteralPath $configPath -Value "`r`n# Added by MCP-LazyBundle on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n$block"
      Write-Host "Codex: added $server MCP to $configPath"
    } else {
      Write-Host "Codex: $server MCP already exists in $configPath"
    }
  }
}

function Install-OpenCode {
  # OpenCode config path requested for this bundle: $HOME\.config\opencode\opencode.json
  $configPath = Join-Path $HOME ".config\opencode\opencode.json"
  $config = Read-JsonObjectOrEmpty -Path $configPath
  Backup-FileIfExists -Path $configPath

  if (!$config.Contains('$schema')) { $config['$schema'] = 'https://opencode.ai/config.json' }
  if (!$config.Contains('mcp') -or $null -eq $config['mcp']) { $config['mcp'] = [ordered]@{} }

  $config['mcp']['github'] = [ordered]@{
    type = 'remote'
    url = 'https://api.githubcopilot.com/mcp/'
    enabled = $true
    headers = [ordered]@{ Authorization = 'Bearer ${GITHUB_PAT_TOKEN}' }
  }
  $config['mcp']['firebase'] = [ordered]@{
    type = 'local'
    command = @('npx.cmd', '-y', 'firebase-tools@latest', 'mcp')
    enabled = $true
  }
  $config['mcp']['obsidian'] = [ordered]@{
    type = 'remote'
    url = 'http://127.0.0.1:27123/mcp/'
    enabled = $true
    headers = [ordered]@{ Authorization = 'Bearer ${OBSIDIAN_API_KEY}' }
  }
  $config['mcp']['notebooklm'] = [ordered]@{
    type = 'local'
    command = @('npx.cmd', '-y', 'notebooklm-mcp@latest')
    enabled = $true
  }

  Write-JsonObject -Object $config -Path $configPath
  Write-Host "OpenCode: added GitHub, Firebase, Obsidian, NotebookLM MCP to $configPath"
}

function Install-ClaudeDesktop {
  if (!$env:APPDATA) {
    Write-Warning "Claude Desktop: APPDATA is not set; skipped."
    return
  }
  $configPath = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
  $config = Read-JsonObjectOrEmpty -Path $configPath
  Backup-FileIfExists -Path $configPath

  if (!$config.Contains('mcpServers') -or $null -eq $config['mcpServers']) { $config['mcpServers'] = [ordered]@{} }
  $config['mcpServers']['github'] = [ordered]@{
    url = 'https://api.githubcopilot.com/mcp/'
    bearer_token_env_var = 'GITHUB_PAT_TOKEN'
  }
  $config['mcpServers']['firebase'] = [ordered]@{
    command = 'npx.cmd'
    args = @('-y', 'firebase-tools@latest', 'mcp')
  }
  $config['mcpServers']['obsidian'] = [ordered]@{
    url = 'http://127.0.0.1:27123/mcp/'
    bearer_token_env_var = 'OBSIDIAN_API_KEY'
  }
  $config['mcpServers']['notebooklm'] = [ordered]@{
    command = 'npx.cmd'
    args = @('-y', 'notebooklm-mcp@latest')
  }

  Write-JsonObject -Object $config -Path $configPath
  Write-Host "Claude Desktop: added GitHub, Firebase, Obsidian, NotebookLM MCP to $configPath"
}

function Install-ProjectMcpJson {
  $configPath = Join-Path $ProjectPath "mcp.json"
  $config = Read-JsonObjectOrEmpty -Path $configPath
  Backup-FileIfExists -Path $configPath

  if (!$config.Contains('mcpServers') -or $null -eq $config['mcpServers']) { $config['mcpServers'] = [ordered]@{} }
  $config['mcpServers']['github'] = [ordered]@{
    url = 'https://api.githubcopilot.com/mcp/'
    bearer_token_env_var = 'GITHUB_PAT_TOKEN'
  }
  $config['mcpServers']['firebase'] = [ordered]@{
    command = 'npx.cmd'
    args = @('-y', 'firebase-tools@latest', 'mcp')
  }
  $config['mcpServers']['obsidian'] = [ordered]@{
    url = 'http://127.0.0.1:27123/mcp/'
    bearer_token_env_var = 'OBSIDIAN_API_KEY'
  }
  $config['mcpServers']['notebooklm'] = [ordered]@{
    command = 'npx.cmd'
    args = @('-y', 'notebooklm-mcp@latest')
  }

  Write-JsonObject -Object $config -Path $configPath
  Write-Host "Project MCP JSON: added GitHub, Firebase, Obsidian, NotebookLM MCP to $configPath"
}

Write-Host "== MCP LazyBundle cross-agent install =="
Write-Host "Targets: $($Targets -join ', ')"
Write-Host "No tokens or secrets will be written."
Write-Host ""

foreach ($target in $Targets) {
  switch ($target.ToLowerInvariant()) {
    'codex' { Install-Codex }
    'opencode' { Install-OpenCode }
    'claudedesktop' { Install-ClaudeDesktop }
    'claude' { Install-ClaudeDesktop }
    'projectmcpjson' { Install-ProjectMcpJson }
    'project' { Install-ProjectMcpJson }
    default { Write-Warning "Unknown target '$target'; skipped." }
  }
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Restart/reload the AI agent you installed into."
Write-Host "2. For NotebookLM, run the MCP setup_auth tool once and sign in in the browser window."
Write-Host "3. For Firebase MCP, run firebase login once per computer if not already logged in."
Write-Host "4. For Obsidian MCP, keep Obsidian Local REST/MCP server running and set OBSIDIAN_API_KEY as a local environment variable if your agent requires it."
Write-Host "5. For GitHub remote MCP, keep GITHUB_PAT_TOKEN only in a local environment variable or credential store; never write the real token into repo files."


