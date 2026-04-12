#!/bin/bash
# Lore launcher — called by Claude Desktop on every start.
# Checks for updates, downloads new binary if available, then execs the server.
# Network failures are non-fatal — the server must always start.
#
# Dependencies: curl, osascript (both ship with macOS)
set -uo pipefail

DATA_DIR="$HOME/.lore"
BIN="$DATA_DIR/bin/lore"
VERSION_FILE="$DATA_DIR/.version"
REPO="bgood-upland/lore"

# ── Read current installed version ──────────────────────────────────────────

CURRENT=""
if [ -f "$VERSION_FILE" ]; then
    CURRENT=$(cat "$VERSION_FILE")
fi

# ── Check GitHub for latest release (2-second timeout) ──────────────────────

LATEST=""
RELEASE_JSON=""
if RELEASE_JSON=$(curl -sfL --max-time 2 \
    "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null); then
    LATEST=$(osascript -l JavaScript -e "
        JSON.parse(\`$RELEASE_JSON\`).tag_name || ''
    " 2>/dev/null || true)
fi

# ── Download new version if needed ──────────────────────────────────────────

if [ -n "$LATEST" ] && { [ "$LATEST" != "$CURRENT" ] || [ ! -x "$BIN" ]; }; then
    ARCH=$(uname -m)
    case "$ARCH" in
        arm64)  ASSET_NAME="lore-aarch64-apple-darwin" ;;
        x86_64) ASSET_NAME="lore-x86_64-apple-darwin" ;;
        *)      ASSET_NAME="" ;;
    esac

    if [ -n "$ASSET_NAME" ] && [ -n "$RELEASE_JSON" ]; then
        DOWNLOAD_URL=$(osascript -l JavaScript -e "
            var r = JSON.parse(\`$RELEASE_JSON\`);
            var a = (r.assets || []).find(function(x) { return x.name === '$ASSET_NAME'; });
            a ? a.browser_download_url : '';
        " 2>/dev/null || true)

        if [ -n "$DOWNLOAD_URL" ]; then
            mkdir -p "$DATA_DIR/bin"
            if curl -sfL --max-time 60 -o "$BIN.tmp" "$DOWNLOAD_URL" 2>/dev/null; then
                mv "$BIN.tmp" "$BIN"
                chmod +x "$BIN"
                echo "$LATEST" > "$VERSION_FILE"
            else
                rm -f "$BIN.tmp"
            fi
        fi
    fi
fi

# ── Start the server ────────────────────────────────────────────────────────

if [ -x "$BIN" ]; then
    exec "$BIN" "$@"
else
    echo "ERROR: No lore binary found at $BIN" >&2
    echo "Run the install script: curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash" >&2
    exit 1
fi
