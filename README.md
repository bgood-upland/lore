# Lore

An MCP server that gives agents structured access to any project's knowledge base (markdown docs, a knowledge graph, and reusable skills stored in the project's repo under .lore/). This provides a shared, version-controlled knowledge base with no additional infrastructure required beyond this MCP server.

## Supported Apps

Lore works with any MCP-compatible app. The installer automatically detects and configures:

- **Claude Desktop** — Anthropic's desktop app
- **Claude Code** — Anthropic's CLI coding agent
- **OpenAI Codex** — OpenAI's coding agent (CLI, app, and IDE extension)

# Install

**macOS:**

1. Open **Terminal**
2. Run the command:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/bgood-upland/lore/main/install.sh | bash
   ```
3. When prompted, select which apps to configure Lore for
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

# Getting Started

## Manual Mode

**Manual Mode** projects are meant for developers that are actively working within a repository. When using manual mode, the knowledge base used for the project is read directly from the codebase and is actively updated as you make modifications and switch between branches. It is up to you to decide the "state" of the knowledge base at any given time. 

After install, open a new terminal window and register your project:

```
lore cli
> add-project my-project --root /path/to/your/repo
> exit
```

If the project doesn't have a `.lore/` knowledge base yet, you'll be prompted to scaffold one.

Restart the configured apps. The server will now have access to your project's knowledge base.

## Project Init Skill (Manual Mode)

Lore ships with a dedicated skill for initializing the knowledge base in a new project. After scaffolding the project, start a new conversation with the agent of your choice, and ask to use the lore project-init skill help guide you and the agent through the process. This skill gives the agent instructions on how to work through the codebase, which files need to be initialized, and how to lead this process in a collaborative manner. Knowledge base creation can also be done manually, however, it is highly recommended to use an agent for many parts of this.

## For PMs (Autopilot Mode)

Autopilot mode creates a read-only clone of a repo so you can access project knowledge without a local checkout:

```
lore cli
> add-project my-project --repo git@github.com:org/repo.git
> exit
```

The clone syncs automatically every 20 minutes and on every app restart, giving you access to the most up to date knowledge base for a project. 

**Prerequisite:** Git and SSH keys must be configured on your machine. If the install script warned about SSH authentication, follow the setup guide at https://docs.github.com/en/authentication/connecting-to-github-with-ssh

# Chat Tips

## Starting a New Session
When starting a new session, it may be helpful to include something along the lines of:
> Use lore to gather context for [project-name] before starting any work

This reminds agents to use the gather_project_context tool at the start of every chat. 

## Update Knowledge Base at the End of a Session
Before ending a session, it's helpful to have the agent make the necessary knowledge base updates before moving on. You can initiate this with something like:
> Use the update session knowledge skill to make knowledge base updates according to the changes made during this session.

This tells the agent to load the "update-session-knowledge" skill (shipped with lore) to guide it through the process of making knowledge base updates at the end of a chat.

## Instructions

For agents to use lore most effectively, it is helpful to add a short block to your project's `CLAUDE.md`, `AGENTS.md`, or the dedicated "project instructions" field in Claude desktop. These instructions should be minimal and help the agent know about the MCP server and its basic usage so you don't need to remind it at the start of every session. The instructions block may look something like:
```markdown
# Session Start Protocol

**Current Project:** rad-hub

1. Use the lore MCP server to call `gather_project_context` with `include_overview: true` **at the beginning of every chat** — this returns the knowledge file index, graph index, skill index, and full project-instructions in one call.
2. Use the `gather_project_context` response to inform the initial knowledge file sections, graph entities, skills, etc. to read at the start of the session. 
3. Follow the guidelines and task routing table in project-instructions to load any additional reference files or skills relevant to the task.

# After Substantive Work

Run the `session-knowledge-update` skill for guided instructions on capturing
what was changed and updating the relevant knowledge base artifacts.
```

# Configuring Additional Apps

To add Lore to an app after the initial setup, or to reconfigure:

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

# Updating

Updates are automatic. When a new version is released, the server updates itself on the next app restart. No action needed.

To check your current version:

```bash
cat ~/.lore/.version
```

# Troubleshooting

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
