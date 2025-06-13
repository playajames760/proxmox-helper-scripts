# Universal Claude Code Development Environment Setup

A flexible one-command installer script that creates isolated Claude Code development environments with support for local installation, Proxmox LXC containers, or Docker containers.

## Features

- 🚀 **Universal deployment** - Works locally, in Proxmox LXC containers, or Docker
- 🎨 **Fancy terminal UI** with colors, progress bars, and ASCII art  
- 📂 **Multiple project modes** - New projects, clone existing repos, or setup current directory
- 🔍 **Environment detection** - Automatically detects Proxmox VE and Docker availability
- 📦 **Automatic dependency installation** (Node.js, npm)
- 🤖 **Claude Code setup** for Max subscription users
- 🔌 **Essential MCP servers** pre-configured for development
- ⚡ **Interactive server selection** with descriptions
- 🐳 **Container isolation** - Clean, reproducible development environments

## Quick Install

### One-line Installation
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/[your-username]/proxmox-helper-scripts/main/setup-claude-dev-env.sh)"
```

### Environment Options

The script will automatically detect and offer available environments:

1. **Local Installation** - Install directly on current system
2. **Proxmox LXC Container** - Create isolated container (when on Proxmox)
3. **Docker Container** - Portable containerized environment (when Docker available)

### Project Setup Modes

Choose how to set up your development project:

1. **New Project** - Start fresh with a new project directory
2. **Clone Existing Repository** - Git clone an existing repo into the environment
3. **Setup Current Directory** - Use the current directory as your project base

## Available MCP Servers

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

- Internet connectivity
- One of: Local system, Proxmox VE host, or Docker installation
- Root or sudo access (for container creation)
- At least 2GB free disk space
- Claude Max subscription (no API key needed)

## Container Access

### Proxmox LXC Container
```bash
# Enter the container
pct enter <container-id>

# Navigate to project
cd /opt/project

# Start Claude Code
claude
```

### Docker Container
```bash
# Enter the container
docker exec -it <container-name> bash

# Navigate to project  
cd /opt/project

# Start Claude Code
claude
```

### Local Installation
```bash
# Navigate to your project directory
cd your-project

# Start Claude Code
claude
```

## Configuration

After installation, configure MCP server credentials in:
- **Local**: `~/.config/claude-code/mcp-config.json`
- **Container**: `/root/.config/claude-code/mcp-config.json`

## Example Usage

### Development Workflows
```bash
# Start a new React project in a container
claude "Help me set up a new React TypeScript project with best practices"

# Clone and work on existing project
claude "Help me understand this codebase and suggest improvements"

# Infrastructure automation
claude "Create a deployment script for this application"
```

### Proxmox-Specific Examples
```bash
# Container management
claude "Help me create a new LXC container for this project"

# API integration
claude "Show me how to use the Proxmox API to manage VMs"

# Automation scripts
claude "Create a backup automation script for Proxmox containers"
```

## Cleanup

### Remove Containers
```bash
# Proxmox LXC
pct stop <container-id> && pct destroy <container-id>

# Docker
docker stop <container-name> && docker rm <container-name>
```

### Local Uninstall
```bash
~/.config/claude-code/uninstall.sh
```

## Troubleshooting

- Check installation log: `/tmp/claude-dev-env-setup-*.log`
- Verify Node.js: `node --version`
- Test Claude Code: `claude --version`
- Check MCP servers: `claude mcp list`
- Container logs: `pct logs <id>` or `docker logs <name>`

## Advanced Configuration

### Environment Variables
- `CLAUDE_CONFIG_DIR` - Custom config directory
- `ANTHROPIC_MODEL` - Specify Claude model
- `MCP_TIMEOUT` - MCP server timeout settings

### Custom MCP Servers
```bash
# Add custom MCP servers
claude mcp add

# Import from Claude Desktop
claude mcp add-from-claude-desktop
```

## License

This script is provided as-is for the development community.

## Contributing

Submit issues and enhancement requests through GitHub!