# Claude Code Proxmox Development Environment Setup

A one-command installer script that sets up Claude Code with essential MCP servers optimized for Proxmox VE development workflows.

## Features

- 🚀 **One-line installation** via curl
- 🎨 **Fancy terminal UI** with colors, progress bars, and ASCII art
- 🔍 **Proxmox VE detection** and environment validation
- 📦 **Automatic dependency installation** (Node.js, npm)
- 🤖 **Claude Code setup** for Max subscription users
- 🔌 **Essential MCP servers** pre-configured for development
- ⚡ **Interactive server selection** with descriptions
- 🛠️ **Post-install configuration** guidance

## Quick Install

Run this command on your Proxmox node:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/[your-username]/proxmox-helper-scripts/main/setup-claude-proxmox-dev.sh)"
```

## Available MCP Servers

The script offers installation of these MCP servers:

### Core Development
- **GitHub MCP Server** - Repository management, issues, PRs
- **Filesystem MCP Server** - Advanced file operations
- **Context7 MCP Server** - Up-to-date documentation lookup

### Infrastructure
- **Proxmox MCP Server** - Direct Proxmox API integration
- **Terraform MCP Server** - Infrastructure as Code
- **AWS MCP Servers** - Cloud infrastructure management

### Development Tools
- **Postman MCP Server** - API testing and development
- **MongoDB MCP Server** - Database operations
- **Supabase MCP Server** - Backend-as-a-Service

### Productivity
- **Obsidian MCP Server** - Knowledge management
- **Notion MCP Server** - Project documentation
- **Mentor MCP Server** - AI-powered code review
- **Perplexity MCP Server** - Enhanced search capabilities

## Requirements

- Proxmox VE host (or Debian-based system)
- Internet connectivity
- Root or sudo access
- At least 2GB free disk space
- Claude Max subscription (no API key needed)

## Post-Installation

After installation, you'll need to:

1. **Configure MCP server credentials** in `~/.config/claude-code/mcp-config.json`
2. **Start using Claude Code**:
   ```bash
   claude                    # Start interactive session
   claude --help            # Show all options
   claude mcp add           # Add more MCP servers
   ```

## Configuration Files

- Claude Code config: `~/.config/claude-code/`
- MCP servers config: `~/.config/claude-code/mcp-config.json`
- Uninstall script: `~/.config/claude-code/uninstall.sh`

## Proxmox-Specific Examples

```bash
# Create a new LXC container
claude "Help me create a Proxmox LXC container for development"

# Work with Proxmox API
claude "Show me how to use the Proxmox API to list VMs"

# Develop automation scripts
claude "Create a backup automation script for Proxmox VMs"
```

## Uninstall

To remove Claude Code and all configurations:

```bash
~/.config/claude-code/uninstall.sh
```

## Troubleshooting

- Check the installation log: `/tmp/claude-proxmox-setup-*.log`
- Verify Node.js installation: `node --version`
- Test Claude Code: `claude --version`
- Check MCP server status: `claude mcp list`

## License

This script is provided as-is for the Proxmox community.

## Contributing

Feel free to submit issues and enhancement requests!