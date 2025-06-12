#!/usr/bin/env bash

# Proxmox Helper Scripts - Claude Code Development Environment Setup
# Container setup script for Claude Code development environment
# Part of the Personal Proxmox Helper Scripts Collection

set -euo pipefail

# Configuration from environment variables
INSTALL_VSCODE="${INSTALL_VSCODE:-yes}"
INSTALL_TEMPLATES="${INSTALL_TEMPLATES:-yes}"
GITHUB_REPO="${GITHUB_REPO:-playajames760/proxmox-helper-scripts}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/claude-code-dev"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Helper functions
msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Update system
msg_info "Updating system packages"
apt-get update -q
apt-get upgrade -y -q
msg_ok "System packages updated"

# Install essential packages
msg_info "Installing essential packages"
apt-get install -y -q \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    zip \
    jq \
    tree \
    htop \
    nano \
    vim \
    tmux \
    sudo \
    openssh-server \
    python3 \
    python3-pip \
    zsh \
    fail2ban \
    ufw \
    fonts-powerline
msg_ok "Essential packages installed"

# Install Node.js 20 LTS
msg_info "Installing Node.js 20 LTS"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
msg_ok "Node.js $(node --version) installed"

# Install GitHub CLI
msg_info "Installing GitHub CLI"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list
apt-get update -q
apt-get install -y gh
msg_ok "GitHub CLI installed"

# Install Docker
msg_info "Installing Docker"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
apt-get update -q
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker
msg_ok "Docker installed"

# Install Claude Code
msg_info "Installing Claude Code"
npm install -g @anthropic-ai/claude-code
msg_ok "Claude Code installed"

# Install additional npm packages
msg_info "Installing development npm packages"
npm install -g \
    yarn \
    pnpm \
    typescript \
    eslint \
    prettier \
    nodemon \
    pm2 \
    http-server
msg_ok "Development packages installed"

# Create developer user
msg_info "Creating developer user"
if ! id "developer" &>/dev/null; then
    useradd -m -s /bin/zsh -G sudo,docker developer
    echo "developer:$(openssl rand -base64 32)" | chpasswd
    echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/developer
    chmod 440 /etc/sudoers.d/developer
fi
msg_ok "Developer user created"

# Set up SSH for developer
msg_info "Setting up SSH for developer"
developer_home="/home/developer"
sudo -u developer mkdir -p "${developer_home}/.ssh"
sudo -u developer chmod 700 "${developer_home}/.ssh"

if [[ ! -f "${developer_home}/.ssh/id_ed25519" ]]; then
    sudo -u developer ssh-keygen -t ed25519 -f "${developer_home}/.ssh/id_ed25519" -N "" -C "developer@claude-code-dev"
fi
msg_ok "SSH keys configured"

# Set up GPG for developer
msg_info "Setting up GPG for developer"
if ! sudo -u developer gpg --list-secret-keys | grep -q "developer@claude-code-dev"; then
    sudo -u developer gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: Developer
Name-Email: developer@claude-code-dev
Expire-Date: 2y
%no-protection
%commit
EOF
    
    GPG_KEY_ID=$(sudo -u developer gpg --list-secret-keys --keyid-format LONG | grep sec | head -n1 | awk '{print $2}' | cut -d'/' -f2)
    sudo -u developer git config --global user.signingkey "$GPG_KEY_ID"
    sudo -u developer git config --global commit.gpgsign true
fi
msg_ok "GPG configured"

# Install Oh My Zsh
msg_info "Installing Oh My Zsh"
if [[ ! -d "${developer_home}/.oh-my-zsh" ]]; then
    sudo -u developer sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    # Install plugins
    sudo -u developer git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${developer_home}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    sudo -u developer git clone https://github.com/zsh-users/zsh-autosuggestions "${developer_home}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    
    # Configure .zshrc
    sudo -u developer sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' "${developer_home}/.zshrc"
    sudo -u developer sed -i 's/plugins=(git)/plugins=(git docker node npm yarn python zsh-syntax-highlighting zsh-autosuggestions)/' "${developer_home}/.zshrc"
fi
msg_ok "Oh My Zsh installed"

# Add development aliases and functions to .zshrc
msg_info "Configuring development environment"
cat >> "${developer_home}/.zshrc" << 'EOF'

# Claude Code Development Environment
alias cc='claude'
alias ccl='claude --continue'
alias ccr='claude --resume'

# Development shortcuts
alias ll='ls -alF'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'

# Docker shortcuts
alias dc='docker-compose'
alias dps='docker ps'

# Node.js shortcuts
alias nrd='npm run dev'
alias nrs='npm run start'
alias nrb='npm run build'
alias nrt='npm run test'

# Claude Code functions
claude-init() {
    if [ $# -eq 0 ]; then
        echo "Usage: claude-init <project-name>"
        return 1
    fi
    
    local project_name="$1"
    mkdir -p "/opt/development/projects/$project_name"
    cd "/opt/development/projects/$project_name"
    
    if [ ! -f "CLAUDE.md" ]; then
        claude "Initialize a new $project_name project with CLAUDE.md configuration and best practices"
    fi
}

dev() {
    cd /opt/development
    if [ $# -eq 1 ]; then
        cd "projects/$1" 2>/dev/null || { echo "Project $1 not found"; return 1; }
    fi
    ls -la
}

new-project() {
    if [ $# -lt 2 ]; then
        echo "Usage: new-project <type> <n>"
        echo "Types: webapp, api, cli, lib"
        return 1
    fi
    
    local project_type="$1"
    local project_name="$2"
    local project_path="/opt/development/projects/$project_name"
    
    mkdir -p "$project_path"
    cd "$project_path"
    
    case "$project_type" in
        webapp)
            claude "Create a full-stack web application project structure for $project_name"
            ;;
        api)
            claude "Create a REST API project structure for $project_name"
            ;;
        cli)
            claude "Create a command-line tool project structure for $project_name"
            ;;
        lib)
            claude "Create a JavaScript/TypeScript library project structure for $project_name"
            ;;
        *)
            echo "Unknown project type: $project_type"
            return 1
            ;;
    esac
}

# Environment variables
export EDITOR=vim
export CLAUDE_CODE_AUTO_UPDATE=true
export PATH="/opt/development/bin:$PATH"

# Welcome message
echo "🚀 Claude Code Development Environment Ready!"
echo "💡 Use 'claude-init <project>' to start a new project"
echo "📁 Use 'dev [project]' to navigate to development directory"
EOF

chown developer:developer "${developer_home}/.zshrc"
msg_ok "Development environment configured"

# Configure Git
msg_info "Configuring Git"
sudo -u developer git config --global init.defaultBranch main
sudo -u developer git config --global user.name "Developer"
sudo -u developer git config --global user.email "developer@claude-code-dev"
sudo -u developer git config --global pull.rebase false
sudo -u developer git config --global core.editor vim
msg_ok "Git configured"

# Create development directory structure
msg_info "Creating development directories"
mkdir -p /opt/development/{projects,templates,bin,docs}
chown -R developer:developer /opt/development
chmod -R 755 /opt/development
msg_ok "Development directories created"

# Install VS Code Server
if [[ "$INSTALL_VSCODE" == "yes" ]]; then
    msg_info "Installing VS Code Server"
    
    curl -fsSL https://code-server.dev/install.sh | sh
    
    # Create systemd service
    cat > /etc/systemd/system/code-server.service << EOF
[Unit]
Description=VS Code Server
After=network.target

[Service]
Type=simple
User=developer
WorkingDirectory=/opt/development
Environment=PASSWORD=claude-code-dev-2025
ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:8080 --user-data-dir /home/developer/.vscode-server --extensions-dir /home/developer/.vscode-server/extensions /opt/development
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable code-server
    systemctl start code-server
    
    msg_ok "VS Code Server installed on port 8080"
fi

# Install project templates
if [[ "$INSTALL_TEMPLATES" == "yes" ]]; then
    msg_info "Installing project templates"
    
    # Create CLAUDE.md template
    curl -fsSL "${BASE_URL}/templates/CLAUDE.md" -o "/opt/development/templates/CLAUDE.md" 2>/dev/null || cat > "/opt/development/templates/CLAUDE.md" << 'EOF'
# Project: {{ PROJECT_NAME }}

## Overview
{{ PROJECT_DESCRIPTION }}

## Development Environment
This project is set up for Claude Code development with:
- Node.js 20 LTS
- Modern development tools
- VS Code Server integration
- Docker support

## Quick Start
1. Install dependencies: `npm install`
2. Start development: `npm run dev`
3. Run tests: `npm test`

## Claude Code Commands
- `/project:test` - Run tests
- `/project:build` - Build project
- `/project:deploy` - Deploy project

## Development Workflow
1. Create feature branch
2. Use Claude Code for development
3. Run tests
4. Commit and push changes
EOF

    # Create custom Claude commands directory
    sudo -u developer mkdir -p "${developer_home}/.claude/commands"
    
    # Download command templates or create defaults
    for cmd in test build deploy; do
        if ! curl -fsSL "${BASE_URL}/templates/commands/${cmd}.md" -o "${developer_home}/.claude/commands/${cmd}.md" 2>/dev/null; then
            cat > "${developer_home}/.claude/commands/${cmd}.md" << EOF
# ${cmd^} Command

Please run the ${cmd} workflow for this project.

Execute the following steps:
1. Check project structure
2. Run ${cmd} process
3. Report results

Arguments: \$ARGUMENTS
EOF
        fi
    done
    
    chown -R developer:developer "${developer_home}/.claude"
    chown -R developer:developer "/opt/development/templates"
    
    msg_ok "Project templates installed"
fi

# Configure firewall
msg_info "Configuring firewall"
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
if [[ "$INSTALL_VSCODE" == "yes" ]]; then
    ufw allow 8080/tcp
fi
msg_ok "Firewall configured"

# Configure SSH
msg_info "Configuring SSH"
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh
msg_ok "SSH configured"

# Create health check script
msg_info "Creating health check script"
cat > /opt/development/bin/health-check << 'EOF'
#!/bin/bash
echo "🔍 Claude Code Development Environment Health Check"
echo "=================================================="
echo ""

echo "💻 System Resources:"
echo "  Memory: $(free -h | awk 'NR==2{printf "%.1f%% (%s/%s)", $3*100/$2, $3, $2}')"
echo "  Disk: $(df -h / | awk 'NR==2{print $5 " (" $3 "/" $2 ")"}')"
echo ""

echo "🔧 Services:"
for service in ssh docker; do
    if systemctl is-active --quiet "$service"; then
        echo "  ✅ $service: Active"
    else
        echo "  ❌ $service: Inactive"
    fi
done

if systemctl is-active --quiet code-server 2>/dev/null; then
    echo "  ✅ code-server: Active"
fi
echo ""

echo "🛠️  Tools:"
echo "  Node.js: $(node --version)"
echo "  Claude Code: $(claude --version 2>/dev/null || echo 'Installed')"
echo "  Git: $(git --version)"
echo ""

echo "📁 Development:"
if [[ -d "/opt/development" ]]; then
    echo "  ✅ Development directory exists"
    echo "  📊 Projects: $(find /opt/development/projects -maxdepth 1 -type d 2>/dev/null | wc -l) directories"
else
    echo "  ❌ Development directory missing"
fi
echo ""

echo "✨ Health check completed!"
EOF

chmod +x /opt/development/bin/health-check
chown developer:developer /opt/development/bin/health-check
msg_ok "Health check script created"

# Create welcome message
msg_info "Setting up welcome message"
cat > /etc/update-motd.d/10-claude-code << 'EOF'
#!/bin/sh
echo ""
echo "🚀 Claude Code Development Environment"
echo "======================================"
echo ""
echo "📁 Development: /opt/development"
echo "👤 User: developer"
echo "🔑 SSH key: ~/.ssh/id_ed25519.pub"
echo ""
if systemctl is-active --quiet code-server 2>/dev/null; then
    echo "💻 VS Code Server: http://$(hostname -I | awk '{print $1}'):8080"
    echo "🔐 Password: claude-code-dev-2025"
    echo ""
fi
echo "🤖 Commands:"
echo "  claude                - Start Claude Code"
echo "  claude-init <project> - New project"
echo "  dev [project]         - Navigate to development"
echo "  health-check          - System status"
echo ""
EOF

chmod +x /etc/update-motd.d/10-claude-code
msg_ok "Welcome message configured"

# Set up automatic updates
msg_info "Configuring automatic updates"
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

apt-get install -y unattended-upgrades
systemctl enable unattended-upgrades
msg_ok "Automatic updates configured"

# Final permissions and cleanup
msg_info "Final setup"
chown -R developer:developer /home/developer /opt/development
chmod -R 755 /opt/development
apt-get autoremove -y -q
apt-get autoclean -q
msg_ok "Setup completed"

echo ""
echo -e "${GREEN}🎉 Claude Code Development Environment Ready!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. SSH: ${YELLOW}ssh developer@\$(hostname -I | awk '{print \$1}')${NC}"
echo -e "2. Authenticate: ${YELLOW}claude${NC}"
echo -e "3. Start coding: ${YELLOW}claude-init my-project${NC}"
echo ""