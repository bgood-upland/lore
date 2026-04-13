# Lore install script — one-time setup for Windows.
# Usage: irm https://raw.githubusercontent.com/bgood-upland/lore/main/install.ps1 | iex
#
# Idempotent — safe to re-run. Does not clobber existing config or other
# MCP servers in any app's config.

$ErrorActionPreference = "Stop"

$Repo = "bgood-upland/lore"
$DataDir = "$env:USERPROFILE\.lore"
$LaunchCmdUrl = "https://raw.githubusercontent.com/$Repo/main/launch.cmd"
$UpdatePs1Url = "https://raw.githubusercontent.com/$Repo/main/update.ps1"

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

# ── Step 3: Download launcher scripts ───────────────────────────────────────

Write-Host "Downloading launcher..."
Invoke-WebRequest -Uri $LaunchCmdUrl -OutFile "$DataDir\bin\launch.cmd"
Invoke-WebRequest -Uri $UpdatePs1Url -OutFile "$DataDir\bin\update.ps1"

# ── Step 4: Download latest binary ──────────────────────────────────────────

Write-Host "Fetching latest release..."
$ReleaseData = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
$LatestTag = $ReleaseData.tag_name

$AssetName = "lore-x86_64-pc-windows-gnu.exe"
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

# ── Step 7: Configure MCP client apps ───────────────────────────────────────
# The binary handles detection and config patching for all supported apps
# (Claude Desktop, Claude Code, OpenAI Codex). Interactive selection via TUI.

Write-Host ""
Write-Host "Configuring MCP client apps..."
Write-Host ""
try {
    & "$DataDir\bin\lore.exe" configure --interactive
} catch {
    Write-Host ""
    Write-Host "  Automatic app configuration was skipped."
    Write-Host "  Run 'lore configure' after install to set up MCP clients."
}

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
Write-Host "  Launcher:        $DataDir\bin\launch.cmd"
Write-Host "  Version:         $LatestTag"
Write-Host ""
Write-Host "  Next steps:"
Write-Host "    1. Restart any configured apps (Claude Desktop, etc.)"
Write-Host "    2. Open a new terminal window"
Write-Host "    3. Add a project:"
Write-Host "       lore cli"
Write-Host "       > add-project my-project --root C:\path\to\repo"
Write-Host ""
Write-Host "  To configure additional apps later:  lore configure"
Write-Host "  Updates are automatic on app restart."
Write-Host ""
