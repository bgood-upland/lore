# Lore install script — one-time setup for Windows.
# Usage: irm https://raw.githubusercontent.com/bgood-upland/lore/main/install.ps1 | iex
#
# Idempotent — safe to re-run. Does not clobber existing config or other
# MCP servers in the Claude Desktop config.

$ErrorActionPreference = "Stop"

$Repo = "bgood-upland/lore"
$DataDir = "$env:USERPROFILE\.lore"
$LauncherUrl = "https://raw.githubusercontent.com/$Repo/main/launch.ps1"
$ClaudeConfig = "$env:APPDATA\Claude\claude_desktop_config.json"

Write-Host ""
Write-Host "Installing Lore..."
Write-Host ""

# ── Step 1: Check prerequisites ─────────────────────────────────────────────

$GitOk = $true
try {
    git --version | Out-Null
} catch {
    $GitOk = $false
    Write-Host "WARNING: git is not installed. Autopilot mode (read-only clones) will not work."
    Write-Host "  Install git: https://git-scm.com/download/win"
    Write-Host "  (Manual mode works fine without git.)"
    Write-Host ""
}

# ── Step 2: Create directory structure ───────────────────────────────────────

Write-Host "Creating directory structure..."
foreach ($dir in @("bin", "repos", "skills", "defaults")) {
    New-Item -ItemType Directory -Path "$DataDir\$dir" -Force | Out-Null
}

# ── Step 3: Download launcher script ────────────────────────────────────────

Write-Host "Downloading launcher..."
Invoke-WebRequest -Uri $LauncherUrl -OutFile "$DataDir\bin\launch.ps1"

# ── Step 4: Download latest binary ──────────────────────────────────────────

Write-Host "Fetching latest release..."
$ReleaseData = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
$LatestTag = $ReleaseData.tag_name

$AssetName = "lore-x86_64-pc-windows-msvc.exe"
$Asset = $ReleaseData.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1

if (-not $Asset) {
    Write-Error "Could not find asset '$AssetName' in release $LatestTag"
    Write-Host "Available assets:"
    foreach ($a in $ReleaseData.assets) {
        Write-Host "  $($a.name)"
    }
    exit 1
}

Write-Host "Downloading $AssetName ($LatestTag)..."
Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile "$DataDir\bin\lore.exe"

# ── Step 5: Write version file ──────────────────────────────────────────────

Set-Content -Path "$DataDir\.version" -Value $LatestTag -NoNewline

# ── Step 6: Seed config if needed ───────────────────────────────────────────

if (-not (Test-Path "$DataDir\config.toml")) {
    $configContent = @"
# Lore project registry
# Add projects via: lore cli -> add-project
#
# Manual mode (developers with local checkouts):
#   [[projects]]
#   name = "my-project"
#   mode = "manual"
#   root = "C:\path\to\project"
#
# Autopilot mode (read-only clones for PMs):
#   [[projects]]
#   name = "my-project"
#   mode = "autopilot"
#   repo = "git@github.com:org/repo.git"
#   branch = "main"
"@
    Set-Content -Path "$DataDir\config.toml" -Value $configContent
    Write-Host "Created config.toml"
}

# ── Step 7: Patch Claude Desktop config ─────────────────────────────────────

Write-Host "Configuring Claude Desktop..."

$LauncherPath = "$DataDir\bin\launch.ps1"

if (Test-Path $ClaudeConfig) {
    try {
        $config = Get-Content $ClaudeConfig -Raw | ConvertFrom-Json
    } catch {
        $config = [PSCustomObject]@{}
    }
} else {
    $configDir = Split-Path $ClaudeConfig -Parent
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    $config = [PSCustomObject]@{}
}

# Ensure mcpServers object exists
if (-not $config.PSObject.Properties["mcpServers"]) {
    $config | Add-Member -MemberType NoteProperty -Name "mcpServers" -Value ([PSCustomObject]@{})
}

# Add/update lore entry — leaves all other mcpServers entries untouched
$loreEntry = [PSCustomObject]@{
    command = "powershell"
    args    = @("-ExecutionPolicy", "Bypass", "-File", $LauncherPath)
    env     = [PSCustomObject]@{ RUST_BACKTRACE = "1" }
}

if ($config.mcpServers.PSObject.Properties["lore"]) {
    $config.mcpServers.lore = $loreEntry
} else {
    $config.mcpServers | Add-Member -MemberType NoteProperty -Name "lore" -Value $loreEntry
}

$config | ConvertTo-Json -Depth 10 | Set-Content $ClaudeConfig -Encoding UTF8
Write-Host "  Updated: $ClaudeConfig"

# ── Step 8: Add to PATH ─────────────────────────────────────────────────────
# Adds ~/.lore/bin to the user's PATH so they can run `lore cli` from any terminal.

$LoreBinDir = "$DataDir\bin"
$CurrentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

if ($CurrentPath -and $CurrentPath.Contains($LoreBinDir)) {
    Write-Host "  PATH already configured."
} else {
    $NewPath = if ($CurrentPath) { "$LoreBinDir;$CurrentPath" } else { $LoreBinDir }
    [Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
    Write-Host "  Added to PATH. Open a new terminal for this to take effect."
}

# ── Step 9: Check SSH for Autopilot mode ────────────────────────────────────

if ($GitOk) {
    Write-Host ""
    Write-Host "Checking GitHub SSH access (for Autopilot mode)..."
    try {
        $sshResult = ssh -T git@github.com -o ConnectTimeout=5 2>&1
        if ($sshResult -match "successfully authenticated") {
            Write-Host "  SSH access confirmed."
        } else {
            Write-Host "  WARNING: SSH authentication to GitHub failed."
            Write-Host "  Autopilot mode requires SSH keys. Setup guide:"
            Write-Host "    https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
            Write-Host "  (Manual mode works fine without SSH.)"
        }
    } catch {
        Write-Host "  WARNING: Could not check SSH access."
        Write-Host "  Autopilot mode requires SSH keys. Setup guide:"
        Write-Host "    https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
    }
}

# ── Done ────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "============================================"
Write-Host "  Lore installed successfully!"
Write-Host "============================================"
Write-Host ""
Write-Host "  Data directory:  $DataDir\"
Write-Host "  Binary:          $DataDir\bin\lore.exe"
Write-Host "  Launcher:        $DataDir\bin\launch.ps1"
Write-Host "  Version:         $LatestTag"
Write-Host ""
Write-Host "  Next steps:"
Write-Host "    1. Restart Claude Desktop"
Write-Host "    2. Open a new terminal window"
Write-Host "    3. Add a project:"
Write-Host "       lore cli"
Write-Host "       > add-project my-project --root C:\path\to\repo"
Write-Host ""
Write-Host "  Updates are automatic on Claude Desktop restart."
Write-Host ""
