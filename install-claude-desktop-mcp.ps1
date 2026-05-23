# Claude Desktop MCP LazyBundle installer
# Compatible with Claude Desktop v1.569.0+ (FleetView/Epitaxy edition)
#
# Key differences from install-agent-lazybundle.ps1:
# - GitHub: NOT written to config; use built-in OAuth Connector in Claude Desktop UI
# - Obsidian: uses mcp-obsidian (file-based) instead of REST API
# - All commands use "cmd /c npx" instead of "npx.cmd"
# - Only updates mcpServers block; never touches preferences block

param(
    [string]$ObsidianVaultPath = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "== Claude Desktop MCP LazyBundle Installer ==" -ForegroundColor Cyan
Write-Host "Targets: firebase, obsidian, notebooklm"
Write-Host "GitHub: use built-in OAuth Connector (see instructions below)"
Write-Host ""

# --- Find Claude Desktop config ---
$configPath = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
if (!(Test-Path (Split-Path $configPath))) {
    throw "Claude Desktop config directory not found. Is Claude Desktop installed?"
}

# --- Warn if Claude Desktop is running ---
$claudeProc = Get-Process -Name "Claude" -ErrorAction SilentlyContinue
if ($claudeProc) {
    Write-Host "[WARN] Claude Desktop is currently running." -ForegroundColor Yellow
    Write-Host "       Claude Desktop rewrites its config on startup." -ForegroundColor Yellow
    Write-Host "       Please FULLY QUIT Claude Desktop before continuing." -ForegroundColor Yellow
    Write-Host ""
    $answer = Read-Host "Have you quit Claude Desktop? (Y/N)"
    if ($answer -notmatch '^(Y|y)$') {
        Write-Host "Aborted. Please quit Claude Desktop and run again." -ForegroundColor Red
        exit 1
    }
}

# --- Detect Obsidian vault path ---
if (!$ObsidianVaultPath) {
    $obsidianJson = Join-Path $env:APPDATA "obsidian\obsidian.json"
    if (Test-Path $obsidianJson) {
        $obsConfig = Get-Content $obsidianJson -Raw -Encoding UTF8 | ConvertFrom-Json
        $vaults = @($obsConfig.vaults.PSObject.Properties | ForEach-Object { $_.Value.path } | Where-Object { Test-Path $_ })

        if ($vaults.Count -eq 0) {
            Write-Warning "No Obsidian vaults found. Obsidian MCP will be skipped."
        } elseif ($vaults.Count -eq 1) {
            $ObsidianVaultPath = $vaults[0]
            Write-Host "[OK] Auto-detected Obsidian vault: $ObsidianVaultPath" -ForegroundColor Green
        } else {
            Write-Host "Multiple Obsidian vaults found:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $vaults.Count; $i++) {
                Write-Host "  [$i] $($vaults[$i])"
            }
            $sel = Read-Host "Enter number to select vault"
            $ObsidianVaultPath = $vaults[[int]$sel]
        }
    } else {
        Write-Warning "obsidian.json not found; Obsidian MCP will be skipped."
    }
}

# --- Build mcpServers block ---
$mcpServers = [ordered]@{}

$mcpServers["firebase"] = [ordered]@{
    command = "cmd"
    args    = @("/c", "npx", "-y", "firebase-tools@latest", "mcp")
}

if ($ObsidianVaultPath) {
    $mcpServers["obsidian"] = [ordered]@{
        command = "cmd"
        args    = @("/c", "npx", "-y", "mcp-obsidian", $ObsidianVaultPath)
    }
}

$mcpServers["notebooklm"] = [ordered]@{
    command = "cmd"
    args    = @("/c", "npx", "-y", "notebooklm-mcp@latest")
}

# --- Read existing config (preserve preferences) ---
$existing = [ordered]@{}
if (Test-Path $configPath) {
    $backupPath = "$configPath.bak-lazybundle-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $configPath $backupPath
    Write-Host "Backup created: $backupPath"
    try {
        $raw = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $raw.PSObject.Properties) {
            if ($prop.Name -ne "mcpServers") {
                $existing[$prop.Name] = $prop.Value
            }
        }
    } catch {
        Write-Warning "Could not parse existing config; starting fresh."
    }
}

# --- Merge and write ---
$final = [ordered]@{ mcpServers = $mcpServers }
foreach ($key in $existing.Keys) {
    $final[$key] = $existing[$key]
}

$json = $final | ConvertTo-Json -Depth 20
Set-Content $configPath $json -Encoding UTF8

Write-Host ""
Write-Host "[OK] claude_desktop_config.json updated:" -ForegroundColor Green
foreach ($name in $mcpServers.Keys) {
    Write-Host "     + $name"
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Start Claude Desktop"
Write-Host "2. Check Settings > Developer > Local MCP servers"
Write-Host "   - firebase, obsidian, notebooklm should be GREEN"
Write-Host "3. Connect GitHub via OAuth:"
Write-Host "   Chat input > [+] > Connectors > GitHub Integration > toggle ON"
Write-Host "4. For NotebookLM: first use -> type 'setup_auth' to complete browser login"
Write-Host ""
