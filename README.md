# Lore

An MCP server that gives agents structured access to any project's knowledge base (markdown docs, a knowledge graph, and reusable skills stored in the project's repo under .lore/). This provides a shared, version-controlled knowledge base with no additional infrastructure required beyond this MCP server.

## Supported Apps

Lore works with any MCP-compatible app. The installer automatically detects and configures:

- **Claude Desktop** — Anthropic's desktop app
- **Claude Code** — Anthropic's CLI coding agent
- **OpenAI Codex** — OpenAI's coding agent (CLI, app, and IDE extension)

## Install

**macOS:**

1. Open **Terminal**
2. Run the command:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/bgood-upland/lore/main/install.sh | bash
   ```
3. When prompted, select which apps to configure Lore for (space to toggle, enter to confirm)
4. When the install finishes, **quit and reopen Terminal** so the `lore` command is available
5. **Restart the configured apps** to make the MCP server available

**Windows:**

1. Open **PowerShell** (press `Win + X`, select "Windows PowerShell" or "Terminal")
2. Run the command:
   ```powershell
   irm https://raw.githubusercontent.com/bgood-upland/lore/main/install.ps1 | iex
   ```
3. When prompted, select which apps to configure Lore for (space to toggle, enter to confirm)
4. When the install finishes, **close and reopen PowerShell** so the `lore` command is available
5. **Restart the configured apps** to make the MCP server available

## Getting Started (Manual Mode)

After install, open a new terminal window and register your project:

```
lore cli
> add-project my-project --root /path/to/your/repo
> exit
```

If the project doesn't have a `.lore/` knowledge base yet, you'll be prompted to scaffold one.

Restart the configured apps. The server will now have access to your project's knowledge base.

## For PMs (Autopilot Mode)

Autopilot mode creates a read-only clone of a repo so you can access project knowledge without a local checkout:

```
lore cli
> add-project my-project --repo git@github.com:org/repo.git
> exit
```

The clone syncs automatically every 20 minutes and on every app restart.

**Prerequisite:** Git and SSH keys must be configured on your machine. If the install script warned about SSH authentication, follow the setup guide at https://docs.github.com/en/authentication/connecting-to-github-with-ssh

## Configuring Additional Apps

To add Lore to an app you installed after the initial setup, or to reconfigure:

```bash
lore configure                          # interactive — detect and select apps
lore configure --app claude-code        # configure a specific app
lore configure --app codex              # configure a specific app
lore configure --list                   # show detection and configuration status
lore configure --all                    # configure all detected apps
```

You can also run `configure` from inside the CLI:

```
lore cli
> configure
```

Valid app names for `--app`: `claude-desktop`, `claude-code`, `codex`

## Updating

Updates are automatic. When a new version is released, the server updates itself on the next app restart. No action needed.

To check your current version:

```bash
cat ~/.lore/.version
```

## Troubleshooting

**An app doesn't see the server**

Run `lore configure --list` to check which apps are detected and configured. If an app shows as "detected (not configured)", run `lore configure --app <name>` to set it up. Restart the app after configuring.

Config file locations for manual inspection:
- Claude Desktop macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Claude Desktop Windows: `%APPDATA%\Claude\claude_desktop_config.json`
- Claude Code: `~/.claude.json`
- OpenAI Codex: `~/.codex/config.toml`

**"lore" command not found**

The install script adds `~/.lore/bin` to your PATH, but this only takes effect in new terminal windows. Close your terminal and open a new one. If it still doesn't work, you can always use the full path:
- macOS: `~/.lore/bin/lore cli`
- Windows: `$env:USERPROFILE\.lore\bin\lore.exe cli`

**Permission denied when running the binary (macOS)**

```bash
chmod +x ~/.lore/bin/lore ~/.lore/bin/launch.sh
```

**Git clone fails for Autopilot projects**

SSH keys aren't configured, or the repo URL is wrong. Test SSH access with `ssh -T git@github.com`. Manual mode projects (with `--root`) don't need SSH.
