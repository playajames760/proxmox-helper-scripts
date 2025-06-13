# Proxmox Helper Scripts

A collection of installer scripts for various applications and development environments, with support for local installation, Proxmox LXC containers, and Docker containers.

## Features

- 🚀 **Universal deployment** - Works locally, in Proxmox LXC containers, or Docker
- 🎨 **Fancy terminal UI** with colors, progress bars, and ASCII art  
- 🔍 **Environment detection** - Automatically detects Proxmox VE and Docker availability
- 📦 **Automated installations** for various applications and services
- 🔧 **Shared utilities** - Common functions across all installers
- ⚡ **Interactive setup** with guided configuration
- 🐳 **Container isolation** - Clean, reproducible environments
- 📁 **Modular design** - Easy to add new installer scripts

## Quick Start

### Interactive Installer (Recommended)
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/[your-username]/proxmox-helper-scripts/main/install.sh)"
```

## Available Installers

### Claude Code Development Environment
Complete development environment with Claude Code, Node.js, and essential MCP servers.

**Direct Installation:**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/[your-username]/proxmox-helper-scripts/main/installers/claude-code/install.sh)"
```

### Coming Soon
- Docker development environments
- Database servers (PostgreSQL, MySQL, MongoDB)
- Web servers (Nginx, Apache)
- Monitoring stacks (Prometheus, Grafana)
- And more...

## Installation Options

All installers automatically detect and offer available environments:

1. **Local Installation** - Install directly on current system
2. **Proxmox LXC Container** - Create isolated container (when on Proxmox)
3. **Docker Container** - Portable containerized environment (when Docker available)

## Directory Structure

```
proxmox-helper-scripts/
├── README.md                    # This file
├── installers/
│   ├── shared/
│   │   └── common.sh           # Shared utilities and functions
│   └── claude-code/
│       └── install.sh          # Claude Code development environment
└── docs/                       # Additional documentation
```

## Claude Code Installer Features

The Claude Code installer includes:

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

### Project Setup Modes
- **New Project** - Start fresh with a new project directory
- **Clone Existing Repository** - Git clone an existing repo into the environment
- **Setup Current Directory** - Use the current directory as your project base

## Requirements

- Internet connectivity
- One of: Local system, Proxmox VE host, or Docker installation
- Root or sudo access (for container creation)
- At least 2GB free disk space
- Specific requirements vary by installer (see individual installer documentation)

## Container Access

### Proxmox LXC Container
```bash
# Enter the container
pct enter <container-id>

# Navigate to project (if applicable)
cd /opt/project
```

### Docker Container
```bash
# Enter the container
docker exec -it <container-name> bash

# Navigate to project (if applicable)
cd /opt/project
```

### Local Installation
```bash
# Navigate to your project directory (if applicable)
cd your-project
```

## Configuration

Configuration varies by installer. See individual installer documentation for specific setup instructions.

## Adding New Installers

To add a new installer to this collection:

1. Create a new directory under `installers/` (e.g., `installers/my-app/`)
2. Create an `install.sh` script in that directory
3. Source the shared utilities: `source "$SCRIPT_DIR/../shared/common.sh"`
4. Use the shared functions for UI, logging, and environment detection
5. Update this README with installation instructions

### Example Installer Structure
```bash
installers/
└── my-app/
    ├── install.sh          # Main installer script
    ├── README.md           # App-specific documentation
    └── config/             # Configuration templates (optional)
        └── default.conf
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
Uninstall methods vary by installer. Check individual installer documentation.

## Troubleshooting

- Check installation logs in `/tmp/proxmox-helper-*.log`
- Verify environment detection with `df -h` and `which docker`
- Container logs: `pct logs <id>` or `docker logs <name>`
- For installer-specific issues, check the installer's documentation

## License

These scripts are provided as-is for the development community.

## Contributing

Submit issues and enhancement requests through GitHub! We welcome new installer contributions.