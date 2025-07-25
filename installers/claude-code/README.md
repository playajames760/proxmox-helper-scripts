# Claude Code Development Environment Installer

Complete development environment setup with Claude Code, Node.js, and essential MCP servers.

## Features

- 🤖 **Claude Code** - Latest version with CLI support
- 📦 **Node.js 20** - Automatic installation and configuration
- 🔌 **MCP Servers** - Pre-configured essential servers for development
- 🎯 **Project Modes** - New project, clone existing, or setup current directory
- 🐳 **Container Support** - Proxmox LXC and Docker containers
- 🔧 **SSH Configuration** - Automated SSH setup for containers

## Requirements

- Claude Max subscription (no API key needed)
- Internet connectivity
- At least 2GB free disk space
- Root access for container creation

## Installation

### Direct Installation
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/[your-username]/proxmox-helper-scripts/main/installers/claude-code/install.sh)"
```

### Via Main Installer
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/[your-username]/proxmox-helper-scripts/main/install.sh)"
```

## MCP Servers Included

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

## Project Setup Modes

1. **New Project** - Start fresh with a new project directory
2. **Clone Existing Repository** - Git clone an existing repo into the environment
3. **Setup Current Directory** - Use the current directory as your project base

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