# Lore update checker — called by launch.cmd before the binary starts.
# Checks for updates, downloads new binary if available, then exits.
# All output is suppressed by launch.cmd — this script must not write to stdout.

$DataDir = "$env:USERPROFILE\.lore"
$Bin = "$DataDir\bin\lore.exe"
$VersionFile = "$DataDir\.version"
$Repo = "bgood-upland/lore"

# ── Read current installed version ──────────────────────────────────────────

$Current = ""
if (Test-Path $VersionFile) {
    $Current = (Get-Content $VersionFile -Raw).Trim()
}

# ── Check GitHub for latest release (2-second timeout) ──────────────────────

$Latest = ""
$ReleaseData = $null
try {
    $ReleaseData = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$Repo/releases/latest" `
        -TimeoutSec 2 `
        -ErrorAction Stop
    $Latest = $ReleaseData.tag_name
} catch {
    # Network failure — continue with existing binary
    exit 0
}

# ── Download new version if needed ──────────────────────────────────────────

if ($Latest -and (($Latest -ne $Current) -or (-not (Test-Path $Bin)))) {
    $AssetName = "lore-x86_64-pc-windows-gnu.exe"
    $Asset = $ReleaseData.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1

    if ($Asset) {
        $DownloadUrl = $Asset.browser_download_url
        $TmpBin = "$Bin.tmp"
        try {
            New-Item -ItemType Directory -Path "$DataDir\bin" -Force | Out-Null
            Invoke-WebRequest `
                -Uri $DownloadUrl `
                -OutFile $TmpBin `
                -TimeoutSec 60 `
                -ErrorAction Stop
            Move-Item -Path $TmpBin -Destination $Bin -Force
            Set-Content -Path $VersionFile -Value $Latest -NoNewline
        } catch {
            Remove-Item -Path $TmpBin -ErrorAction SilentlyContinue
        }
    }
}
