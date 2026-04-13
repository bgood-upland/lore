#!/bin/bash
# Lore install script — one-time setup for macOS.
# Usage: curl -fsSL https://raw.githubusercontent.com/bgood-upland/lore/main/install.sh | bash
#
# Idempotent — safe to re-run. Does not clobber existing config or other
# MCP servers in the Claude Desktop config.
#
# Dependencies: curl, osascript (both ship with macOS)
set -euo pipefail

REPO="bgood-upland/lore"
DATA_DIR="$HOME/.lore"
LAUNCHER_URL="https://raw.githubusercontent.com/$REPO/main/launch.sh"

echo ""
echo "Installing Lore..."
echo ""

# ── Step 1: Check prerequisites ─────────────────────────────────────────────

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required but not found."
    exit 1
fi

if ! command -v osascript &>/dev/null; then
    echo "ERROR: osascript is required but not found."
    echo "This should ship with macOS. Something is very wrong with your system."
    exit 1
fi

GIT_OK=true
if ! command -v git &>/dev/null; then
    GIT_OK=false
    echo "WARNING: git is not installed. Autopilot mode (read-only clones) will not work."
    echo "  Install git: https://git-scm.com/download/mac"
    echo "  (Manual mode works fine without git.)"
    echo ""
fi

# ── Step 2: Create directory structure ───────────────────────────────────────

echo "Creating directory structure..."
mkdir -p "$DATA_DIR/bin"
mkdir -p "$DATA_DIR/repos"
mkdir -p "$DATA_DIR/skills"
mkdir -p "$DATA_DIR/defaults"

# ── Step 3: Download launcher script ────────────────────────────────────────

echo "Downloading launcher..."
curl -sfL -o "$DATA_DIR/bin/launch.sh" "$LAUNCHER_URL"
chmod +x "$DATA_DIR/bin/launch.sh"

# ── Step 4: Download latest binary ──────────────────────────────────────────

echo "Fetching latest release..."
RELEASE_JSON=$(curl -sfL "https://api.github.com/repos/$REPO/releases/latest")

LATEST_TAG=$(osascript -l JavaScript -e "
    JSON.parse(\`$RELEASE_JSON\`).tag_name || ''
")

if [ -z "$LATEST_TAG" ]; then
    echo "ERROR: Could not determine latest release version."
    echo "Check that the repo has at least one release: https://github.com/$REPO/releases"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    arm64)  ASSET_NAME="lore-aarch64-apple-darwin" ;;
    x86_64) ASSET_NAME="lore-x86_64-apple-darwin" ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Downloading $ASSET_NAME ($LATEST_TAG)..."
DOWNLOAD_URL=$(osascript -l JavaScript -e "
    var r = JSON.parse(\`$RELEASE_JSON\`);
    var a = (r.assets || []).find(function(x) { return x.name === '$ASSET_NAME'; });
    a ? a.browser_download_url : '';
")

if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Could not find asset '$ASSET_NAME' in release $LATEST_TAG"
    echo "Available assets:"
    osascript -l JavaScript -e "
        var r = JSON.parse(\`$RELEASE_JSON\`);
        (r.assets || []).map(function(a) { return '  ' + a.name; }).join('\n');
    " 2>/dev/null || true
    exit 1
fi

curl -sfL -o "$DATA_DIR/bin/lore" "$DOWNLOAD_URL"
chmod +x "$DATA_DIR/bin/lore"

# ── Step 5: Write version file ──────────────────────────────────────────────

echo "$LATEST_TAG" > "$DATA_DIR/.version"

# ── Step 6: Seed config if needed ───────────────────────────────────────────
# The binary's ensure_initialized will also do this on first run, but creating
# it now lets users run `lore cli` immediately after install.

if [ ! -f "$DATA_DIR/config.toml" ]; then
    cat > "$DATA_DIR/config.toml" << 'EOF'
# Lore project registry
# Add projects via: lore cli → add-project
#
# Manual mode (developers with local checkouts):
#   [[projects]]
#   name = "my-project"
#   mode = "manual"
#   root = "/path/to/project"
#
# Autopilot mode (read-only clones for PMs):
#   [[projects]]
#   name = "my-project"
#   mode = "autopilot"
#   repo = "git@github.com:org/repo.git"
#   branch = "main"
EOF
    echo "Created config.toml"
fi

# ── Step 7: Configure MCP client apps ───────────────────────────────────────
# The binary handles detection and config patching for all supported apps
# (Claude Desktop, Claude Code, OpenAI Codex). Interactive selection via TUI.
#
# The < /dev/tty redirect is required because when this script is piped from
# curl (curl | bash), stdin is the pipe, not the terminal. /dev/tty gives
# dialoguer direct access to the terminal for the interactive prompt.

echo ""
if "$DATA_DIR/bin/lore" configure --interactive < /dev/tty 2>&1; then
    : # success
else
    echo ""
    echo "  Automatic app configuration was skipped."
    echo "  Run 'lore configure' after install to set up MCP clients."
fi

# ── Step 8: Add to PATH ─────────────────────────────────────────────────────
# Adds ~/.lore/bin to PATH so users can run `lore cli` from any terminal.

SHELL_RC=""
case "$(basename "$SHELL")" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    bash) SHELL_RC="$HOME/.bash_profile" ;;
esac

if [ -n "$SHELL_RC" ]; then
    PATH_LINE='export PATH="$HOME/.lore/bin:$PATH"'
    if [ -f "$SHELL_RC" ] && grep -qF '.lore/bin' "$SHELL_RC"; then
        echo "  PATH already configured in $SHELL_RC"
    else
        echo "" >> "$SHELL_RC"
        echo "# Lore CLI" >> "$SHELL_RC"
        echo "$PATH_LINE" >> "$SHELL_RC"
        echo "  Added to PATH in $SHELL_RC"
        echo "  Run 'source $SHELL_RC' or open a new terminal for this to take effect."
    fi
fi

# ── Step 9: Check SSH for Autopilot mode ────────────────────────────────────

if [ "$GIT_OK" = true ]; then
    echo ""
    echo "Checking GitHub SSH access (for Autopilot mode)..."
    if ssh -T git@github.com -o ConnectTimeout=5 2>&1 | grep -q "successfully authenticated"; then
        echo "  SSH access confirmed."
    else
        echo "  WARNING: SSH authentication to GitHub failed."
        echo "  Autopilot mode requires SSH keys. Setup guide:"
        echo "    https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
        echo "  (Manual mode works fine without SSH.)"
    fi
fi

# ── Done ────────────────────────────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Lore installed successfully!"
echo "============================================"
echo ""
echo "  Data directory:  $DATA_DIR/"
echo "  Binary:          $DATA_DIR/bin/lore"
echo "  Launcher:        $DATA_DIR/bin/launch.sh"
echo "  Version:         $LATEST_TAG"
echo ""
echo "  Next steps:"
echo "    1. Restart any configured apps (Claude Desktop, etc.)"
if [ -n "$SHELL_RC" ]; then
    echo "    2. Open a new terminal window (or run: source $SHELL_RC)"
else
    echo "    2. Open a new terminal window"
fi
echo "    3. Add a project:"
echo "       lore cli"
echo "       > add-project my-project --root /path/to/repo"
echo ""
echo "  To configure additional apps later:  lore configure"
echo "  Updates are automatic on app restart."
echo ""
