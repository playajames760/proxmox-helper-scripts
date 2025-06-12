# Claude Code Development Environment

Complete AI-powered development environment with Claude Code integration, designed for Proxmox LXC containers. This is part of the Personal Proxmox Helper Scripts collection.

## 🎯 Overview

This script creates a comprehensive development environment specifically optimized for Claude Code workflows. It combines modern development tools with AI-powered coding assistance to create a powerful, containerized development platform.

## 🚀 Quick Installation

### Interactive Setup
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/scripts/claude-code-dev/install.sh)
```

### Automatic Setup (Uses Defaults)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/scripts/claude-code-dev/install.sh) --auto
```

## ✨ Features

### Core Development Stack
- **Claude Code**: Latest version with authentication setup
- **Node.js 20 LTS**: Complete JavaScript/TypeScript development environment
- **Development Tools**: npm, yarn, pnpm, TypeScript, ESLint, Prettier
- **Version Control**: Git with GPG signing configuration
- **Container Platform**: Docker and Docker Compose
- **Shell Environment**: Oh My Zsh with development plugins

### AI Development Integration
- **Project Templates**: Pre-configured CLAUDE.md files
- **Custom Commands**: Specialized workflows (/project:test, /project:build, etc.)
- **Extended Thinking**: Optimized for complex development tasks
- **MCP Support**: Model Context Protocol server integration
- **Automated Documentation**: AI-powered documentation generation

### Optional Components
- **VS Code Server**: Web-based IDE accessible via browser
- **Development Volume**: Separate persistent storage for projects
- **Project Templates**: Multiple project types (webapp, api, cli, lib)
- **Health Monitoring**: Built-in system health checks

## 📋 System Requirements

### Proxmox Host
- **Proxmox VE**: 8.0 or higher recommended
- **Available RAM**: 8GB+ for optimal performance
- **Storage**: 20GB+ for container (50GB+ if using dev volume)
- **Network**: Internet connectivity for downloads and Claude Code API

### Container Resources (Configurable)
- **CPU**: 4 cores (default)
- **RAM**: 8GB (default)
- **Storage**: 20GB root filesystem
- **Development Volume**: 50GB (optional)
- **Network**: Bridge mode with DHCP or static IP

### External Dependencies
- **Anthropic Account**: Active account with billing enabled
- **API Access**: Internet connectivity to api.anthropic.com
- **Package Repositories**: Access to Node.js, Docker, and Ubuntu repositories

## 🔐 Access & Authentication

### SSH Access
```bash
# Connect to container
ssh developer@<container-ip>

# View SSH public key
cat ~/.ssh/id_ed25519.pub

# Copy public key to clipboard (for GitHub)
cat ~/.ssh/id_ed25519.pub | pbcopy  # macOS
cat ~/.ssh/id_ed25519.pub | xclip   # Linux
```

### Claude Code Authentication
```bash
# First-time authentication
claude

# Follow prompts to:
# 1. Choose authentication method (Console or App)
# 2. Complete OAuth flow in browser
# 3. Verify API access

# Test authentication
claude "Hello, can you help me code?"
```

### VS Code Server Access
```
URL: http://<container-ip>:8080
Password: claude-code-dev-2025
```

## 💻 Usage Examples

### Project Management

#### Initialize New Project
```bash
# Create project with Claude Code setup
claude-init my-web-app

# Navigate to project
dev my-web-app

# Start development with Claude
claude "Create a React app with TypeScript and Tailwind CSS"
```

#### Create Templated Projects
```bash
# Web application
new-project webapp my-ecommerce-site

# REST API
new-project api user-management-api

# CLI tool
new-project cli deployment-helper

# Library
new-project lib utility-functions
```

### Development Workflows

#### Testing Workflow
```bash
# Run comprehensive tests
claude /project:test

# Test specific components
claude /project:test unit

# With extended thinking
claude "think carefully about edge cases, then run comprehensive tests"
```

#### Build and Deployment
```bash
# Build for production
claude /project:build production

# Deploy to staging
claude /project:deploy staging

# Create documentation
claude /project:docs
```

#### Code Review and Quality
```bash
# Analyze code quality
claude "review my recent changes and suggest improvements"

# Security audit
claude /project:security

# Performance optimization
claude "analyze performance bottlenecks and suggest optimizations"
```

## 🔧 Customization

### Environment Variables
```bash
# Add to ~/.zshrc or ~/.bashrc
export CLAUDE_CODE_AUTO_UPDATE=true
export CLAUDE_CODE_DIAGNOSTICS=yes
export CLAUDE_CODE_MODEL=opus  # or sonnet
export EDITOR=vim
export BROWSER=firefox
```

### Custom Aliases
```bash
# Development shortcuts
alias cc='claude'
alias ccl='claude --continue'
alias ccr='claude --resume'
alias cct='claude "think about this problem"'

# Project navigation
alias dev='cd /opt/development && ls -la'
alias proj='cd /opt/development/projects'

# Quick commands
alias hc='health-check'
alias logs='journalctl -f'
```

## 🐛 Troubleshooting

### Common Issues

#### Claude Code Authentication
```bash
# Reset authentication
rm ~/.config/@anthropic-ai/claude-code/config.json
claude

# Check API connectivity
curl -s https://api.anthropic.com
```

#### VS Code Server
```bash
# Restart service
sudo systemctl restart code-server

# Check logs
journalctl -u code-server -f

# Reset password
sudo systemctl edit code-server
```

#### Network Issues
```bash
# Test connectivity
ping google.com
curl -I https://api.anthropic.com

# Check firewall
sudo ufw status
```

## 📚 Additional Resources

### Documentation
- [Claude Code Official Documentation](https://docs.anthropic.com/en/docs/claude-code/overview)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/)
- [Node.js Documentation](https://nodejs.org/en/docs/)

### Community
- [Proxmox Community Forum](https://forum.proxmox.com/)
- [Claude Code GitHub Repository](https://github.com/anthropics/claude-code)

---

**🎉 Happy coding with Claude Code on Proxmox!**

*This script is part of the Personal Proxmox Helper Scripts collection. For more automation tools and scripts, visit the [main repository](https://github.com/playajames760/proxmox-helper-scripts).*