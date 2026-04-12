# Lore

An MCP server that gives agents structured access to your project's knowledge base — markdown docs, a knowledge graph, and reusable skills stored in your repo under `.lore/`.

## Install

**macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/bgood-upland/lore/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/bgood-upland/lore/main/install.ps1 | iex
```

After install, restart Claude Desktop.

## Getting Started

1. Open a terminal and run the CLI:
   ```bash
   ~/.lore/bin/lore cli
   ```

2. Register a project:
   ```
   > add-project my-project --root /path/to/your/repo
   ```

3. If the project doesn't have a `.lore/` knowledge base yet, you'll be prompted to scaffold one.

4. Restart Claude Desktop. The server will now have access to your project's knowledge base.

## For PMs (Autopilot Mode)

Autopilot mode creates a read-only clone of a repo so you can access project knowledge without a local checkout:

```
> add-project my-project --repo git@github.com:org/repo.git
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

Open `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows) and verify there's a `"lore"` entry inside `"mcpServers"`. Restart Claude Desktop after any changes.

**Permission denied when running the binary**

```bash
chmod +x ~/.lore/bin/lore ~/.lore/bin/launch.sh
```

**Git clone fails for Autopilot projects**

SSH keys aren't configured, or the repo URL is wrong. Test SSH access with `ssh -T git@github.com`. Manual mode projects (with `--root`) don't need SSH.