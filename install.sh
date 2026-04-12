#!/bin/bash
# Lore install script — one-time setup for macOS.
# Usage: curl -fsSL https://raw.githubusercontent.com/bgood-upland/lore/main/install.sh | bash
#
# Idempotent — safe to re-run. Does not clobber existing config or other
# MCP servers in the Claude Desktop config.
#
# Dependencies: curl, osascript, plutil (all ship with macOS)
set -euo pipefail

REPO="bgood-upland/lore"
DATA_DIR="$HOME/.lore"
LAUNCHER_URL="https://raw.githubusercontent.com/$REPO/main/launch.sh"
CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

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

# ── Step 7: Patch Claude Desktop config ─────────────────────────────────────
# Adds the "lore" MCP server entry without clobbering other servers.
# Uses plutil (ships with macOS) for JSON manipulation — no Python dependency.

echo "Configuring Claude Desktop..."

LAUNCHER_PATH="$DATA_DIR/bin/launch.sh"

# Create the config file if it doesn't exist
if [ ! -f "$CLAUDE_CONFIG" ]; then
    mkdir -p "$(dirname "$CLAUDE_CONFIG")"
    echo '{}' > "$CLAUDE_CONFIG"
fi

# Ensure mcpServers key exists (no-op if already present)
plutil -insert mcpServers -json '{}' "$CLAUDE_CONFIG" >/dev/null 2>&1 || true

# Remove existing lore entry if present (so -insert doesn't fail on duplicate)
plutil -remove mcpServers.lore "$CLAUDE_CONFIG" >/dev/null 2>&1 || true

# Add lore entry
plutil -insert mcpServers.lore -json "{
  \"command\": \"$LAUNCHER_PATH\",
  \"args\": [],
  \"env\": {\"RUST_BACKTRACE\": \"1\"}
}" "$CLAUDE_CONFIG"

echo "  Updated: $CLAUDE_CONFIG"

# ── Step 8: Check SSH for Autopilot mode ────────────────────────────────────

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
echo "    1. Restart Claude Desktop"
echo "    2. Add a project:"
echo "       $DATA_DIR/bin/lore cli"
echo "       > add-project my-project --root /path/to/repo"
echo ""
echo "  Updates are automatic on Claude Desktop restart."
echo ""
