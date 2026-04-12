# Lore

An MCP server that gives agents structured access to any project's knowledge base (markdown docs, a knowledge graph, and reusable skills stored in the project's repo under .lore/). This provides a shared, version-controlled knowledge base with no additional infrastructure required beyond this MCP server.

## Install

**macOS:**

1. Open **Terminal**
2. Run the command:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/bgood-upland/lore/main/install.sh | bash
   ```
3. When the install finishes, **quit and reopen Terminal** so the `lore` command is available
4. **Restart Claude Desktop** to make the MCP server available

**Windows:**

1. Open **PowerShell** (press `Win + X`, select "Windows PowerShell" or "Terminal")
2. Run the command:
   ```powershell
   irm https://raw.githubusercontent.com/bgood-upland/lore/main/install.ps1 | iex
   ```
3. When the install finishes, **close and reopen PowerShell** so the `lore` command is available
4. **Restart Claude Desktop** to make the MCP server available

## Getting Started (Manual Mode)

After install, open a new terminal window and register your project:

```
lore cli
> add-project my-project --root /path/to/your/repo
> exit
```

If the project doesn't have a `.lore/` knowledge base yet, you'll be prompted to scaffold one.

Restart Claude Desktop. The server will now have access to your project's knowledge base.

## For PMs (Autopilot Mode)

Autopilot mode creates a read-only clone of a repo so you can access project knowledge without a local checkout:

```
lore cli
> add-project my-project --repo git@github.com:org/repo.git
> exit
```

The clone syncs automatically every 20 minutes and on every Claude Desktop restart.

**Prerequisite:** Git and SSH keys must be configured on your machine. If the install script warned about SSH authentication, follow the setup guide at https://docs.github.com/en/authentication/connecting-to-github-with-ssh

## Updating

Updates are automatic. When a new version is released, the server updates itself on the next Claude Desktop restart. No action needed.

To check your current version:

```bash
cat ~/.lore/.version
```

## Troubleshooting

**Claude Desktop doesn't see the server**

Open your Claude Desktop config file and verify there's a `"lore"` entry inside `"mcpServers"`:
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

Restart Claude Desktop after any changes.

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
