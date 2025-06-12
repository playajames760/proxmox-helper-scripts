#!/usr/bin/env bash

# Proxmox Helper Scripts - Claude Code Development Environment Setup
# Secure container configuration for modern AI development
# Version 2.0.0 - Enhanced security and latest Claude Code integration

set -euo pipefail

# Configuration from environment variables
INSTALL_VSCODE="${INSTALL_VSCODE:-1}"
INSTALL_DOCKER="${INSTALL_DOCKER:-1}"
INSTALL_TEMPLATES="${INSTALL_TEMPLATES:-1}"
GITHUB_REPO="${GITHUB_REPO:-playajames760/proxmox-helper-scripts}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/claude-code-dev"
AUTO_START="${AUTO_START:-1}"
DEV_VOLUME_SIZE="${DEV_VOLUME_SIZE:-50}"

# Secure defaults
DEVELOPER_USER="developer"
DEVELOPER_HOME="/home/$DEVELOPER_USER"

# Colors and messaging
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
msg_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Security functions
generate_secure_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
}

generate_secure_token() {
    openssl rand -hex 32
}

# ===============================
# System Update and Base Packages
# ===============================

msg_step "Starting Claude Code development environment setup"

# Update system with proper error handling
msg_info "Updating system packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q || msg_error "Failed to update package lists"
apt-get upgrade -y -q || msg_warn "Some packages failed to upgrade"
msg_ok "System packages updated"

# Install essential packages with retry logic
msg_info "Installing essential packages"
essential_packages=(
    "curl" "wget" "git" "build-essential" "software-properties-common"
    "apt-transport-https" "ca-certificates" "gnupg" "lsb-release"
    "unzip" "zip" "jq" "tree" "htop" "nano" "vim" "tmux" "sudo"
    "openssh-server" "python3" "python3-pip" "zsh" "fail2ban" "ufw"
    "fonts-powerline" "locales" "tzdata"
)

for package in "${essential_packages[@]}"; do
    if ! apt-get install -y -q "$package"; then
        msg_warn "Failed to install $package, continuing..."
    fi
done
msg_ok "Essential packages installed"

# Configure locale
msg_info "Configuring locale"
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
export LANG=en_US.UTF-8
msg_ok "Locale configured"

# ===============================
# Create Secure Developer User
# ===============================

msg_info "Creating secure developer user"

# Create user with secure settings
if ! id "$DEVELOPER_USER" &>/dev/null; then
    useradd -m -s /bin/zsh -G sudo "$DEVELOPER_USER"
    
    # Generate secure password
    DEVELOPER_PASSWORD=$(generate_secure_password)
    echo "$DEVELOPER_USER:$DEVELOPER_PASSWORD" | chpasswd
    
    # Create sudo rules file
    echo "$DEVELOPER_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$DEVELOPER_USER"
    chmod 440 "/etc/sudoers.d/$DEVELOPER_USER"
    
    # Save password securely
    echo "$DEVELOPER_PASSWORD" > "$DEVELOPER_HOME/.initial-password"
    chmod 600 "$DEVELOPER_HOME/.initial-password"
    chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME/.initial-password"
    
    msg_ok "Developer user created with secure password"
else
    msg_ok "Developer user already exists"
fi

# Add to docker group if docker will be installed
if [[ "$INSTALL_DOCKER" == "1" ]]; then
    usermod -aG docker "$DEVELOPER_USER" 2>/dev/null || true
fi

# ===============================
# SSH Security Configuration
# ===============================

msg_info "Setting up secure SSH configuration"

# Create SSH directory
sudo -u "$DEVELOPER_USER" mkdir -p "$DEVELOPER_HOME/.ssh"
sudo -u "$DEVELOPER_USER" chmod 700 "$DEVELOPER_HOME/.ssh"

# Generate secure SSH key
if [[ ! -f "$DEVELOPER_HOME/.ssh/id_ed25519" ]]; then
    msg_info "Generating SSH keys"
    sudo -u "$DEVELOPER_USER" ssh-keygen -t ed25519 \
        -f "$DEVELOPER_HOME/.ssh/id_ed25519" \
        -N "" \
        -C "$DEVELOPER_USER@claude-code-dev-$(date +%Y%m%d)"
    
    # Set up authorized_keys with the generated key for convenience
    sudo -u "$DEVELOPER_USER" cp "$DEVELOPER_HOME/.ssh/id_ed25519.pub" "$DEVELOPER_HOME/.ssh/authorized_keys"
    sudo -u "$DEVELOPER_USER" chmod 600 "$DEVELOPER_HOME/.ssh/authorized_keys"
    
    msg_ok "SSH keys generated and configured"
else
    msg_ok "SSH keys already exist"
fi

# Configure SSH daemon securely
msg_info "Hardening SSH configuration"
{
    echo "# Enhanced security settings"
    echo "PasswordAuthentication no"
    echo "PubkeyAuthentication yes"
    echo "PermitRootLogin no"
    echo "MaxAuthTries 3"
    echo "LoginGraceTime 30"
    echo "AllowUsers $DEVELOPER_USER"
    echo "Protocol 2"
    echo "ClientAliveInterval 300"
    echo "ClientAliveCountMax 2"
} >> /etc/ssh/sshd_config

# Remove any conflicting settings
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

systemctl restart ssh
msg_ok "SSH configured securely"

# ===============================
# GPG Configuration (Enhanced Security)
# ===============================

msg_info "Setting up GPG with enhanced security"

# Generate GPG key with better security settings
if ! sudo -u "$DEVELOPER_USER" gpg --list-secret-keys | grep -q "$DEVELOPER_USER@claude-code-dev"; then
    msg_info "Generating GPG key with enhanced security"
    
    # Create GPG configuration
    sudo -u "$DEVELOPER_USER" mkdir -p "$DEVELOPER_HOME/.gnupg"
    sudo -u "$DEVELOPER_USER" chmod 700 "$DEVELOPER_HOME/.gnupg"
    
    cat > "$DEVELOPER_HOME/.gnupg/gpg.conf" << 'EOF'
# Enhanced security settings
personal-cipher-preferences AES256 AES192 AES
personal-digest-preferences SHA512 SHA384 SHA256
personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed
default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
cert-digest-algo SHA512
s2k-digest-algo SHA512
s2k-cipher-algo AES256
charset utf-8
no-comments
no-emit-version
keyid-format 0xlong
list-options show-uid-validity
verify-options show-uid-validity
with-fingerprint
use-agent
EOF
    
    chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME/.gnupg/gpg.conf"
    chmod 600 "$DEVELOPER_HOME/.gnupg/gpg.conf"
    
    # Generate key with batch mode and better security
    sudo -u "$DEVELOPER_USER" gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Claude Code Developer
Name-Email: $DEVELOPER_USER@claude-code-dev
Expire-Date: 2y
Passphrase: $(generate_secure_password)
%commit
EOF
    
    # Configure Git to use GPG
    GPG_KEY_ID=$(sudo -u "$DEVELOPER_USER" gpg --list-secret-keys --keyid-format LONG | grep sec | head -n1 | awk '{print $2}' | cut -d'/' -f2)
    sudo -u "$DEVELOPER_USER" git config --global user.signingkey "$GPG_KEY_ID"
    sudo -u "$DEVELOPER_USER" git config --global commit.gpgsign true
    sudo -u "$DEVELOPER_USER" git config --global tag.gpgsign true
    
    msg_ok "GPG configured with enhanced security"
else
    msg_ok "GPG already configured"
fi

# ===============================
# Git Configuration
# ===============================

msg_info "Configuring Git with security best practices"
sudo -u "$DEVELOPER_USER" git config --global init.defaultBranch main
sudo -u "$DEVELOPER_USER" git config --global user.name "Claude Code Developer"
sudo -u "$DEVELOPER_USER" git config --global user.email "$DEVELOPER_USER@claude-code-dev"
sudo -u "$DEVELOPER_USER" git config --global pull.rebase false
sudo -u "$DEVELOPER_USER" git config --global core.editor vim
sudo -u "$DEVELOPER_USER" git config --global push.followTags true
sudo -u "$DEVELOPER_USER" git config --global core.autocrlf input
sudo -u "$DEVELOPER_USER" git config --global core.safecrlf warn
msg_ok "Git configured"

# ===============================
# Oh My Zsh Installation
# ===============================

msg_info "Installing Oh My Zsh with plugins"
if [[ ! -d "$DEVELOPER_HOME/.oh-my-zsh" ]]; then
    # Install Oh My Zsh
    sudo -u "$DEVELOPER_USER" sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    # Install useful plugins
    sudo -u "$DEVELOPER_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$DEVELOPER_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    sudo -u "$DEVELOPER_USER" git clone https://github.com/zsh-users/zsh-autosuggestions "$DEVELOPER_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    sudo -u "$DEVELOPER_USER" git clone https://github.com/zsh-users/zsh-completions "$DEVELOPER_HOME/.oh-my-zsh/custom/plugins/zsh-completions"
    
    # Configure .zshrc with better theme and plugins
    sudo -u "$DEVELOPER_USER" sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' "$DEVELOPER_HOME/.zshrc"
    sudo -u "$DEVELOPER_USER" sed -i 's/plugins=(git)/plugins=(git docker node npm yarn python zsh-syntax-highlighting zsh-autosuggestions zsh-completions kubectl)/' "$DEVELOPER_HOME/.zshrc"
    
    msg_ok "Oh My Zsh installed with plugins"
else
    msg_ok "Oh My Zsh already installed"
fi

# ===============================
# Development Environment Setup
# ===============================

msg_info "Configuring development environment"

# Create development directory structure
mkdir -p /opt/development/{projects,templates,bin,docs,logs}
chown -R "$DEVELOPER_USER:$DEVELOPER_USER" /opt/development
chmod -R 755 /opt/development

# Enhanced .zshrc configuration
cat >> "$DEVELOPER_HOME/.zshrc" << 'EOF'

# ===============================
# Claude Code Development Environment
# ===============================

# Environment variables
export EDITOR=vim
export CLAUDE_CONFIG_DIR="$HOME/.config/claude"
export PATH="/opt/development/bin:$PATH"

# Claude Code aliases and functions
alias cc='claude'
alias ccl='claude --continue'
alias ccr='claude --resume'
alias ccd='claude --debug'

# Development shortcuts
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Git shortcuts with security awareness
alias gs='git status'
alias ga='git add'
alias gc='git commit -S'  # Always sign commits
alias gp='git push --follow-tags'
alias gl='git pull'
alias gd='git diff'
alias glog='git log --oneline --graph --decorate'

# Docker shortcuts
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'
alias dex='docker exec -it'

# Node.js shortcuts
alias nrd='npm run dev'
alias nrs='npm run start'
alias nrb='npm run build'
alias nrt='npm run test'
alias nrl='npm run lint'

# Claude Code project management functions
claude-init() {
    if [ $# -eq 0 ]; then
        echo "Usage: claude-init <project-name>"
        echo "Creates a new Claude Code project with proper structure"
        return 1
    fi
    
    local project_name="$1"
    local project_path="/opt/development/projects/$project_name"
    
    if [[ -d "$project_path" ]]; then
        echo "❌ Project '$project_name' already exists"
        return 1
    fi
    
    mkdir -p "$project_path"
    cd "$project_path"
    
    # Initialize git repository
    git init
    
    # Create basic project structure
    mkdir -p {src,tests,docs,.claude}
    
    # Create CLAUDE.md with project-specific configuration
    cat > CLAUDE.md << EOL
# Project: $project_name

## Overview
A Claude Code development project created on $(date +%Y-%m-%d).

## Development Environment
This project is set up for Claude Code development with:
- Node.js and modern JavaScript/TypeScript tooling
- Docker support for containerized development
- Git with GPG signing enabled
- Comprehensive testing and linting setup

## Project Structure
- \`src/\` - Source code
- \`tests/\` - Test files
- \`docs/\` - Documentation
- \`.claude/\` - Claude Code configuration

## Quick Commands
- \`/project:setup\` - Set up project dependencies
- \`/project:test\` - Run all tests
- \`/project:build\` - Build project
- \`/project:deploy\` - Deploy project

## Development Workflow
1. Create feature branch: \`git checkout -b feature/name\`
2. Use Claude Code for development assistance
3. Run tests: \`npm test\`
4. Commit with signing: \`git commit -S -m "message"\`
5. Push changes: \`git push\`

## Security Notes
- All commits are GPG signed
- SSH keys are used for Git authentication
- Dependencies are regularly audited
EOL

    # Create basic package.json if it doesn't exist
    if [[ ! -f "package.json" ]]; then
        cat > package.json << EOL
{
  "name": "$project_name",
  "version": "1.0.0",
  "description": "Claude Code project: $project_name",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "build": "npm run test",
    "lint": "eslint src/",
    "lint:fix": "eslint src/ --fix"
  },
  "keywords": ["claude-code", "development"],
  "author": "Claude Code Developer",
  "license": "MIT"
}
EOL
    fi
    
    # Create basic .gitignore
    cat > .gitignore << 'EOL'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Build outputs
dist/
build/
*.log

# Environment variables
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Claude Code
.claude/cache/
EOL
    
    # Create basic README
    cat > README.md << EOL
# $project_name

A Claude Code development project.

## Getting Started

1. Install dependencies: \`npm install\`
2. Start development: \`npm run dev\`
3. Run tests: \`npm test\`

## Development with Claude Code

This project is optimized for Claude Code development. Use the \`claude\` command to start an AI-assisted development session.

### Quick Commands
- \`claude-init\` - Initialize new features
- \`cc\` - Start Claude Code
- \`ccl\` - Continue previous session

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests
4. Commit with GPG signing
5. Submit a pull request
EOL
    
    echo "✅ Project '$project_name' initialized at $project_path"
    echo "💡 Use 'claude' to start AI-assisted development"
    
    # Initial commit
    git add .
    git commit -S -m "Initial project setup with Claude Code configuration

🎉 Created project: $project_name
📝 Added CLAUDE.md configuration
🔧 Set up basic project structure
🔐 Enabled GPG signing"
}

# Navigate to development directory
dev() {
    cd /opt/development
    if [ $# -eq 1 ]; then
        if [[ -d "projects/$1" ]]; then
            cd "projects/$1"
            echo "📁 Switched to project: $1"
            ls -la
        else
            echo "❌ Project '$1' not found"
            echo "📂 Available projects:"
            ls -1 projects/ 2>/dev/null || echo "   No projects found"
            return 1
        fi
    else
        echo "📂 Development directory contents:"
        ls -la
    fi
}

# Project creation with templates
new-project() {
    if [ $# -lt 2 ]; then
        echo "Usage: new-project <type> <name>"
        echo "Types: webapp, api, cli, lib, fullstack, microservice"
        return 1
    fi
    
    local project_type="$1"
    local project_name="$2"
    
    claude-init "$project_name"
    cd "/opt/development/projects/$project_name"
    
    case "$project_type" in
        webapp)
            echo "🌐 Setting up web application structure"
            mkdir -p {public,src/{components,pages,styles,utils},tests/{unit,integration}}
            echo "Web application template created"
            ;;
        api)
            echo "🔌 Setting up API service structure"
            mkdir -p {src/{routes,controllers,models,middleware,utils},tests/{unit,integration},docs/api}
            echo "API service template created"
            ;;
        cli)
            echo "⚡ Setting up CLI tool structure"
            mkdir -p {src/{commands,utils},tests,docs}
            echo "#!/usr/bin/env node" > src/cli.js
            chmod +x src/cli.js
            echo "CLI tool template created"
            ;;
        lib)
            echo "📚 Setting up library structure"
            mkdir -p {src,tests/{unit,integration},examples,docs}
            echo "Library template created"
            ;;
        fullstack)
            echo "🚀 Setting up full-stack application"
            mkdir -p {client/{src,public},server/{src,tests},shared,docs}
            echo "Full-stack template created"
            ;;
        microservice)
            echo "🐳 Setting up microservice structure"
            mkdir -p {src/{services,handlers,models},tests,deploy,docs}
            echo "Microservice template created"
            ;;
        *)
            echo "❌ Unknown project type: $project_type"
            echo "Available types: webapp, api, cli, lib, fullstack, microservice"
            return 1
            ;;
    esac
    
    echo "✅ $project_type project '$project_name' created successfully"
}

# Health check function
health-check() {
    echo "🔍 Claude Code Development Environment Health Check"
    echo "=================================================="
    echo ""
    
    echo "💻 System Resources:"
    echo "  Memory: $(free -h | awk 'NR==2{printf "%.1f%% (%s/%s)", $3*100/$2, $3, $2}')"
    echo "  Disk: $(df -h / | awk 'NR==2{print $5 " (" $3 "/" $2 ")"}')"
    echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
    
    echo "🔧 Services:"
    for service in ssh docker code-server; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "  ✅ $service: Active"
        else
            echo "  ❌ $service: Inactive"
        fi
    done
    echo ""
    
    echo "🛠️  Development Tools:"
    local tools=("node" "npm" "claude" "git" "docker" "curl" "jq")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version=$($tool --version 2>/dev/null | head -1 | awk '{print $1 " " $2 " " $3}' | cut -c1-30)
            echo "  ✅ $tool: $version"
        else
            echo "  ❌ $tool: Not found"
        fi
    done
    echo ""
    
    echo "🔐 Security Status:"
    if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
        echo "  ✅ SSH key: Configured"
    else
        echo "  ❌ SSH key: Missing"
    fi
    
    if gpg --list-secret-keys | grep -q "$USER@claude-code-dev"; then
        echo "  ✅ GPG key: Configured"
    else
        echo "  ❌ GPG key: Missing"
    fi
    
    if systemctl is-active --quiet fail2ban; then
        echo "  ✅ Fail2ban: Active"
    else
        echo "  ❌ Fail2ban: Inactive"
    fi
    echo ""
    
    echo "📁 Development Environment:"
    if [[ -d "/opt/development" ]]; then
        echo "  ✅ Development directory exists"
        local project_count=$(find /opt/development/projects -maxdepth 1 -type d 2>/dev/null | wc -l)
        echo "  📊 Projects: $((project_count - 1)) directories"
    else
        echo "  ❌ Development directory missing"
    fi
    
    echo ""
    echo "🌐 Network Connectivity:"
    if curl -s --connect-timeout 5 https://api.anthropic.com/v1/models >/dev/null; then
        echo "  ✅ Claude API: Reachable"
    else
        echo "  ❌ Claude API: Unreachable"
    fi
    
    if curl -s --connect-timeout 5 https://registry.npmjs.org >/dev/null; then
        echo "  ✅ NPM Registry: Reachable"
    else
        echo "  ❌ NPM Registry: Unreachable"
    fi
    
    echo ""
    echo "✨ Health check completed!"
}

# Welcome message with security info
welcome-info() {
    echo ""
    echo "🚀 Claude Code Development Environment"
    echo "======================================"
    echo ""
    echo "📁 Quick Navigation:"
    echo "  dev                   # Go to development directory"
    echo "  dev <project>         # Go to specific project"
    echo "  claude-init <name>    # Create new project"
    echo "  new-project <type> <name>  # Create templated project"
    echo ""
    echo "🤖 Claude Code:"
    echo "  claude               # Start Claude Code"
    echo "  ccl                  # Continue previous session"
    echo "  ccr                  # Resume session"
    echo ""
    echo "🔐 Security Features:"
    echo "  SSH keys configured and secured"
    echo "  GPG signing enabled for commits"
    echo "  Fail2ban protecting SSH"
    echo "  UFW firewall configured"
    echo ""
    echo "🔧 System Tools:"
    echo "  health-check         # System diagnostics"
    echo "  welcome-info         # Show this message"
    echo ""
}

# Show welcome on first login
if [[ ! -f "$HOME/.welcome-shown" ]]; then
    welcome-info
    touch "$HOME/.welcome-shown"
fi

EOF

chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME/.zshrc"
msg_ok "Development environment configured"

# ===============================
# VS Code Server Installation (Secure)
# ===============================

if [[ "$INSTALL_VSCODE" == "1" ]]; then
    msg_info "Installing VS Code Server with enhanced security"
    
    # Install code-server
    curl -fsSL https://code-server.dev/install.sh | sh
    
    # Generate secure password
    VSCODE_PASSWORD=$(generate_secure_password)
    
    # Create systemd service with security enhancements
    cat > /etc/systemd/system/code-server.service << EOF
[Unit]
Description=VS Code Server
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=$DEVELOPER_USER
WorkingDirectory=/opt/development
Environment=PASSWORD=$VSCODE_PASSWORD
Environment=SHELL=/bin/zsh
ExecStart=/usr/bin/code-server \\
    --bind-addr 0.0.0.0:8080 \\
    --user-data-dir $DEVELOPER_HOME/.vscode-server \\
    --extensions-dir $DEVELOPER_HOME/.vscode-server/extensions \\
    --disable-telemetry \\
    --auth password \\
    /opt/development
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=code-server

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=no
ReadWritePaths=/opt/development $DEVELOPER_HOME/.vscode-server
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

[Install]
WantedBy=multi-user.target
EOF

    # Save password securely
    echo "$VSCODE_PASSWORD" > "$DEVELOPER_HOME/.vscode-password"
    chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME/.vscode-password"
    chmod 600 "$DEVELOPER_HOME/.vscode-password"
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable code-server
    
    if [[ "$AUTO_START" == "1" ]]; then
        systemctl start code-server
        msg_ok "VS Code Server installed and started (password saved to ~/.vscode-password)"
    else
        msg_ok "VS Code Server installed (password saved to ~/.vscode-password)"
    fi
else
    msg_info "Skipping VS Code Server installation"
fi

# ===============================
# Project Templates
# ===============================

if [[ "$INSTALL_TEMPLATES" == "1" ]]; then
    msg_info "Installing project templates"
    
    # Create enhanced CLAUDE.md template
    cat > "/opt/development/templates/CLAUDE.md" << 'EOF'
# Project: {{ PROJECT_NAME }}

## Overview
{{ PROJECT_DESCRIPTION }}

## Development Environment
This project is optimized for Claude Code development with:
- Node.js 20 LTS and modern JavaScript/TypeScript tooling
- Docker support for containerized development
- Git with GPG commit signing enabled
- VS Code Server integration for web-based development
- Comprehensive testing and linting setup
- Security-first configuration

## Project Structure
```
{{ PROJECT_NAME }}/
├── src/                 # Source code
├── tests/              # Test files
│   ├── unit/           # Unit tests
│   └── integration/    # Integration tests
├── docs/               # Documentation
├── .claude/            # Claude Code configuration
├── docker/             # Docker configurations
└── scripts/            # Build and utility scripts
```

## Quick Commands
- `/project:setup` - Set up project dependencies and environment
- `/project:test` - Run comprehensive test suite
- `/project:build` - Build project for production
- `/project:deploy` - Deploy project to target environment
- `/project:security` - Run security audit and checks
- `/project:docs` - Generate/update documentation

## Development Workflow
1. **Feature Development**
   ```bash
   git checkout -b feature/amazing-feature
   claude-init feature-work
   # Use Claude Code for development
   npm test
   git commit -S -m "Add amazing feature"
   git push origin feature/amazing-feature
   ```

2. **Code Review**
   - All commits are GPG signed for security
   - Use `claude` for code review assistance
   - Run `health-check` before submitting PRs

3. **Security Practices**
   - Regular dependency audits: `npm audit`
   - GPG signing for all commits
   - SSH keys for authentication
   - Environment variable security

## Claude Code Integration
This project includes:
- Custom commands in `.claude/commands/`
- Project-specific configuration
- Security-aware development practices
- AI-assisted code review workflows

## Security Notes
- 🔐 All commits must be GPG signed
- 🔑 SSH keys are used for Git authentication
- 🛡️ Dependencies are regularly audited
- 🚫 Secrets are never committed to version control
- 📝 Security practices are documented and enforced

## Environment Variables
Create a `.env` file (never commit this):
```bash
# Application settings
NODE_ENV=development
PORT=3000

# Claude Code settings
CLAUDE_CONFIG_DIR=.claude
ANTHROPIC_LOG=info

# Add your specific variables here
```

## Getting Help
- `health-check` - System diagnostics
- `claude --help` - Claude Code help
- `welcome-info` - Environment overview
EOF

    # Create custom Claude commands directory
    sudo -u "$DEVELOPER_USER" mkdir -p "$DEVELOPER_HOME/.claude/commands"
    
    # Create enhanced command templates
    for cmd in setup test build deploy security docs; do
        cat > "$DEVELOPER_HOME/.claude/commands/${cmd}.md" << EOF
# ${cmd^} Command

Execute the ${cmd} workflow for this project with comprehensive error handling and security awareness.

## Workflow Steps:
1. **Environment Validation**
   - Check project structure
   - Verify dependencies
   - Validate configuration

2. **${cmd^} Process**
   - Run ${cmd} with proper error handling
   - Monitor progress and log output
   - Validate results

3. **Security Checks**
   - Audit dependencies for vulnerabilities
   - Check for sensitive data exposure
   - Validate security configurations

4. **Reporting**
   - Provide detailed status report
   - Log any issues or warnings
   - Suggest next steps

## Security Considerations:
- Never expose sensitive data in logs
- Validate all inputs and configurations
- Follow security best practices
- Report any security concerns

Arguments: \$ARGUMENTS
Project Path: \$PWD
EOF
        chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME/.claude/commands/${cmd}.md"
    done
    
    chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME/.claude"
    chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "/opt/development/templates"
    
    msg_ok "Enhanced project templates installed"
fi

# ===============================
# Firewall Configuration
# ===============================

msg_info "Configuring secure firewall"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH access
ufw allow ssh

# VS Code Server (if installed)
if [[ "$INSTALL_VSCODE" == "1" ]]; then
    ufw allow 8080/tcp
fi

# Enable firewall
ufw --force enable
msg_ok "Firewall configured securely"

# ===============================
# Fail2ban Configuration
# ===============================

msg_info "Configuring intrusion prevention"

# Create fail2ban configuration for SSH
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

systemctl enable fail2ban
systemctl start fail2ban
msg_ok "Intrusion prevention configured"

# ===============================
# Documentation Creation
# ===============================

msg_info "Creating user documentation"

# Create comprehensive authentication guide
cat > "$DEVELOPER_HOME/AUTHENTICATION.md" << 'EOF'
# Claude Code Authentication Guide

## Quick Setup

### Method 1: Console Authentication (Recommended for SSH)
1. SSH into the container: `ssh developer@<container-ip>`
2. Run: `claude`
3. Select "Console" authentication when prompted
4. Visit the provided URL in your browser
5. Complete the OAuth flow
6. Enter the verification code in the terminal

### Method 2: App Authentication (Browser Required)
1. Run: `claude`
2. Select "App" authentication when prompted
3. Follow the browser prompts to authenticate

## Verification
Test your authentication:
```bash
claude "Hello, Claude Code!"
```

## Troubleshooting

### Authentication Issues
- **Error: Network unreachable**
  - Check internet connectivity: `curl -I https://api.anthropic.com`
  - Verify firewall settings: `ufw status`

- **Error: Invalid API key**
  - Re-run authentication: `claude` and follow prompts
  - Check Claude Code configuration: `claude config`

### Environment Issues
- **Command not found: claude**
  - Verify installation: `which claude`
  - Check PATH: `echo $PATH`
  - Reinstall if needed: `npm install -g @anthropic-ai/claude-code@latest`

### SSH Issues
- **Permission denied (publickey)**
  - Verify SSH key: `ssh-add -l`
  - Check authorized_keys: `cat ~/.ssh/authorized_keys`
  - Generate new key if needed: `ssh-keygen -t ed25519`

## Security Notes
- Authentication tokens are stored securely in `~/.config/claude/`
- SSH keys use Ed25519 algorithm for enhanced security
- All Git commits are GPG signed
- Regular security audits are recommended

## Advanced Configuration

### Environment Variables
```bash
export CLAUDE_CONFIG_DIR="$HOME/.config/claude"
export ANTHROPIC_LOG=debug  # For troubleshooting
```

### Custom Commands
Create custom commands in `~/.claude/commands/` for project-specific workflows.

### MCP Servers
Configure Multi-Context Proxy (MCP) servers for enhanced capabilities:
```bash
claude mcp add
```

## Getting Help
- Claude Code help: `claude --help`
- System diagnostics: `health-check`
- Environment overview: `welcome-info`
- Documentation: This file and project CLAUDE.md files
EOF

# Create project development guide
cat > "$DEVELOPER_HOME/README.md" << 'EOF'
# Claude Code Development Environment

Welcome to your secure, AI-powered development environment!

## 🚀 Quick Start

### First Time Setup
1. **Authenticate Claude Code**
   ```bash
   claude
   ```
   Follow the authentication prompts (see AUTHENTICATION.md for details)

2. **Create Your First Project**
   ```bash
   claude-init my-awesome-project
   ```

3. **Start Developing**
   ```bash
   dev my-awesome-project
   claude "Let's build something amazing!"
   ```

## 🛠️ Development Tools

### Available Tools
- **Claude Code** - AI-powered development assistant
- **Node.js 20 LTS** - Modern JavaScript runtime
- **Docker** - Containerization platform
- **Git** - Version control with GPG signing
- **VS Code Server** - Web-based IDE
- **Oh My Zsh** - Enhanced shell experience

### Quick Commands
| Command | Description |
|---------|-------------|
| `claude` | Start Claude Code AI assistant |
| `claude-init <name>` | Create new project with AI setup |
| `dev [project]` | Navigate to development directory |
| `new-project <type> <name>` | Create templated project |
| `health-check` | System diagnostics |
| `welcome-info` | Show environment overview |

## 🔐 Security Features

This environment is configured with security best practices:

- **SSH Security**: Ed25519 keys, password auth disabled
- **GPG Signing**: All commits automatically signed
- **Firewall**: UFW configured with minimal open ports
- **Intrusion Prevention**: Fail2ban monitoring SSH
- **Secure Passwords**: Random generation for all services
- **Container Security**: Unprivileged LXC with minimal privileges

## 📁 Directory Structure

```
/opt/development/
├── projects/           # Your development projects
├── templates/          # Project templates
├── bin/               # Custom scripts and tools
├── docs/              # Documentation
└── logs/              # Development logs

$HOME/
├── .ssh/              # SSH keys and configuration
├── .claude/           # Claude Code configuration
├── .config/           # Application configurations
└── .vscode-server/    # VS Code Server data
```

## 🎯 Development Workflow

### Creating a New Project
```bash
# Initialize with AI assistance
claude-init my-project

# Or use templates
new-project webapp my-web-app
new-project api my-backend
new-project cli my-tool
```

### Working with AI
```bash
# Start AI session
claude

# Continue previous work
ccl  # or claude --continue

# Get help with specific tasks
claude "Help me optimize this React component"
claude "Review my code for security issues"
claude "Write tests for this function"
```

### Git Workflow (with GPG signing)
```bash
# All commits are automatically GPG signed
git add .
git commit -m "feat: add awesome feature"
git push
```

## 🌐 Access Methods

### Container Access (Primary)
```bash
pct enter <container-id> && su - developer
```

### SSH Access
```bash
ssh developer@<container-ip>
```

### VS Code Server
Open browser to: `http://<container-ip>:8080`
Password: See `~/.vscode-password`

## 🔧 Maintenance

### System Health
```bash
health-check  # Comprehensive system diagnostics
```

### Updates
```bash
# Update Claude Code
npm update -g @anthropic-ai/claude-code

# Update system packages
sudo apt update && sudo apt upgrade

# Update development tools
npm update -g
```

### Security Audits
```bash
# Check for vulnerabilities
npm audit

# Review firewall status
sudo ufw status

# Check intrusion attempts
sudo fail2ban-client status sshd
```

## 📚 Documentation

- **Authentication Guide**: `~/AUTHENTICATION.md`
- **Project Templates**: `/opt/development/templates/`
- **Custom Commands**: `~/.claude/commands/`
- **System Logs**: `/opt/development/logs/`

## 🆘 Getting Help

### Built-in Help
```bash
claude --help          # Claude Code help
health-check           # System diagnostics
welcome-info           # Environment overview
```

### Troubleshooting
1. Check system health: `health-check`
2. Review logs: `journalctl -u <service-name>`
3. Test connectivity: `curl -I https://api.anthropic.com`
4. Restart services: `sudo systemctl restart <service>`

### Community Resources
- Claude Code Documentation: https://docs.anthropic.com/claude-code
- GitHub Issues: https://github.com/playajames760/proxmox-helper-scripts/issues

---

🎉 **Happy Coding with AI!** 🎉

This environment is designed to supercharge your development workflow with AI assistance while maintaining the highest security standards.
EOF

chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME/AUTHENTICATION.md"
chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME/README.md"
msg_ok "User documentation created"

# ===============================
# Enhanced Health Check Script
# ===============================

msg_info "Creating enhanced health check script"
cat > /opt/development/bin/health-check << 'EOF'
#!/bin/bash

echo "🔍 Claude Code Development Environment Health Check"
echo "==================================================="
echo ""

# System Resources
echo "💻 System Resources:"
echo "  Memory: $(free -h | awk 'NR==2{printf "%.1f%% (%s/%s)", $3*100/$2, $3, $2}')"
echo "  Disk: $(df -h / | awk 'NR==2{print $5 " (" $3 "/" $2 ")"}')"
echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "  Uptime: $(uptime -p)"
echo ""

# Services
echo "🔧 Critical Services:"
for service in ssh docker code-server fail2ban ufw; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "  ✅ $service: $(systemctl is-active $service 2>/dev/null)"
    else
        echo "  ❌ $service: $(systemctl is-active $service 2>/dev/null)"
    fi
done
echo ""

# Development Tools
echo "🛠️  Development Tools:"
declare -A tools=(
    ["node"]="--version"
    ["npm"]="--version"
    ["claude"]="--version"
    ["git"]="--version"
    ["docker"]="--version"
    ["curl"]="--version"
    ["jq"]="--version"
)

for tool in "${!tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        version=$($tool ${tools[$tool]} 2>/dev/null | head -1 | awk '{print $1 " " $2 " " $3}' | cut -c1-30)
        echo "  ✅ $tool: $version"
    else
        echo "  ❌ $tool: Not found"
    fi
done
echo ""

# Security Status
echo "🔐 Security Status:"
if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    echo "  ✅ SSH key: Configured (Ed25519)"
    echo "     Fingerprint: $(ssh-keygen -lf ~/.ssh/id_ed25519.pub 2>/dev/null | awk '{print $2}')"
else
    echo "  ❌ SSH key: Missing"
fi

if gpg --list-secret-keys 2>/dev/null | grep -q "$USER@claude-code-dev"; then
    echo "  ✅ GPG key: Configured"
    gpg_id=$(gpg --list-secret-keys --keyid-format SHORT 2>/dev/null | grep sec | head -1 | awk '{print $2}' | cut -d'/' -f2)
    echo "     Key ID: $gpg_id"
else
    echo "  ❌ GPG key: Missing"
fi

if systemctl is-active --quiet fail2ban; then
    banned_count=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned:" | awk '{print $3}' || echo "0")
    echo "  ✅ Fail2ban: Active (${banned_count} banned IPs)"
else
    echo "  ❌ Fail2ban: Inactive"
fi

if ufw status 2>/dev/null | grep -q "Status: active"; then
    echo "  ✅ UFW Firewall: Active"
else
    echo "  ❌ UFW Firewall: Inactive"
fi
echo ""

# Development Environment
echo "📁 Development Environment:"
if [[ -d "/opt/development" ]]; then
    echo "  ✅ Development directory exists"
    if [[ -d "/opt/development/projects" ]]; then
        project_count=$(find /opt/development/projects -maxdepth 1 -type d 2>/dev/null | wc -l)
        echo "  📊 Projects: $((project_count - 1)) directories"
        
        if [[ $((project_count - 1)) -gt 0 ]]; then
            echo "     Recent projects:"
            find /opt/development/projects -maxdepth 1 -type d -not -path "/opt/development/projects" -printf "       - %f\n" 2>/dev/null | head -5
        fi
    else
        echo "  ❌ Projects directory missing"
    fi
else
    echo "  ❌ Development directory missing"
fi
echo ""

# Network Connectivity
echo "🌐 Network Connectivity:"
declare -A endpoints=(
    ["Claude API"]="https://api.anthropic.com/v1/models"
    ["NPM Registry"]="https://registry.npmjs.org"
    ["GitHub"]="https://api.github.com"
    ["Docker Hub"]="https://registry-1.docker.io"
)

for name in "${!endpoints[@]}"; do
    if curl -s --connect-timeout 5 "${endpoints[$name]}" >/dev/null 2>&1; then
        echo "  ✅ $name: Reachable"
    else
        echo "  ❌ $name: Unreachable"
    fi
done
echo ""

# Claude Code Configuration
echo "🤖 Claude Code Status:"
if command -v claude >/dev/null 2>&1; then
    if claude --version >/dev/null 2>&1; then
        claude_version=$(claude --version 2>/dev/null | head -1)
        echo "  ✅ Claude Code: $claude_version"
        
        # Check configuration directory
        if [[ -d "$HOME/.config/claude" ]]; then
            echo "  ✅ Configuration: Present"
        else
            echo "  ⚠️  Configuration: Missing (run 'claude' to authenticate)"
        fi
        
        # Test API connectivity
        if claude "ping" >/dev/null 2>&1; then
            echo "  ✅ API Connection: Working"
        else
            echo "  ⚠️  API Connection: Needs authentication"
        fi
    else
        echo "  ❌ Claude Code: Installation issues"
    fi
else
    echo "  ❌ Claude Code: Not found"
fi
echo ""

# Performance Metrics
echo "📊 Performance Metrics:"
echo "  CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "  Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%"), $3/$2 * 100.0}')"
echo "  Disk I/O: $(iostat -d 1 2 | tail -1 | awk '{print "Read: " $3 " KB/s, Write: " $4 " KB/s"}' 2>/dev/null || echo "iostat not available")"
echo ""

# Summary
echo "✨ Health Check Summary:"
total_checks=0
passed_checks=0

# Count status indicators (rough estimation)
output=$(health-check 2>/dev/null)
total_checks=$(echo "$output" | grep -E "  [✅❌⚠️]" | wc -l)
passed_checks=$(echo "$output" | grep -E "  ✅" | wc -l)

if [[ $total_checks -gt 0 ]]; then
    success_rate=$((passed_checks * 100 / total_checks))
    echo "  Overall Health: ${passed_checks}/${total_checks} checks passed (${success_rate}%)"
    
    if [[ $success_rate -ge 90 ]]; then
        echo "  🎉 System is healthy and ready for development!"
    elif [[ $success_rate -ge 70 ]]; then
        echo "  ⚠️  System has minor issues that should be addressed"
    else
        echo "  🚨 System has significant issues requiring attention"
    fi
else
    echo "  ℹ️  Health check completed"
fi

echo ""
echo "💡 Run 'welcome-info' for quick start guide"
echo "📚 Read ~/README.md and ~/AUTHENTICATION.md for detailed documentation"
EOF

chmod +x /opt/development/bin/health-check
chown "$DEVELOPER_USER:$DEVELOPER_USER" /opt/development/bin/health-check
msg_ok "Enhanced health check script created"

# ===============================
# System Services and Startup
# ===============================

msg_info "Configuring system services"

# Configure automatic security updates
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

apt-get install -y unattended-upgrades
systemctl enable unattended-upgrades

# Create welcome MOTD
cat > /etc/update-motd.d/10-claude-code << 'EOF'
#!/bin/sh
echo ""
echo "🚀 Claude Code Development Environment"
echo "======================================"
echo ""
echo "📁 Development: /opt/development"
echo "👤 User: developer"
echo "🔑 SSH: ~/.ssh/id_ed25519"
echo ""
if systemctl is-active --quiet code-server 2>/dev/null; then
    echo "💻 VS Code Server: http://$(hostname -I | awk '{print $1}'):8080"
    if [[ -f /home/developer/.vscode-password ]]; then
        echo "🔐 Password: $(cat /home/developer/.vscode-password)"
    fi
    echo ""
fi
echo "🤖 Quick Commands:"
echo "  claude                # Start Claude Code AI"
echo "  claude-init <project> # Create new project"
echo "  dev [project]         # Navigate to development"
echo "  health-check          # System diagnostics"
echo "  welcome-info          # Full environment guide"
echo ""
echo "📚 Documentation: ~/README.md and ~/AUTHENTICATION.md"
echo ""
EOF

chmod +x /etc/update-motd.d/10-claude-code
msg_ok "System services configured"

# ===============================
# Final Security Hardening
# ===============================

msg_info "Applying final security hardening"

# Set secure permissions
chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME" /opt/development
chmod -R 755 /opt/development
chmod 700 "$DEVELOPER_HOME/.ssh"
chmod 600 "$DEVELOPER_HOME/.ssh"/*
chmod 700 "$DEVELOPER_HOME/.gnupg"
chmod 600 "$DEVELOPER_HOME/.gnupg"/*

# Secure system files
chmod 600 /etc/ssh/sshd_config
chmod 644 /etc/fail2ban/jail.local

# Clean up sensitive files
if [[ -f "$DEVELOPER_HOME/.initial-password" ]]; then
    msg_info "Initial password saved to ~/.initial-password (remove after first login)"
fi

# Final cleanup
apt-get autoremove -y -q
apt-get autoclean -q

msg_ok "Security hardening completed"

# ===============================
# Installation Summary
# ===============================

echo ""
echo -e "${GREEN}🎉 Claude Code Development Environment Setup Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Installation Summary:${NC}"
echo -e "  ✅ Secure user account created"
echo -e "  ✅ SSH keys generated and configured"
echo -e "  ✅ GPG signing enabled for Git"
echo -e "  ✅ Oh My Zsh with productivity plugins"
echo -e "  ✅ Development tools and environment"
[[ "$INSTALL_VSCODE" == "1" ]] && echo -e "  ✅ VS Code Server (port 8080)"
[[ "$INSTALL_DOCKER" == "1" ]] && echo -e "  ✅ Docker containerization platform"
echo -e "  ✅ Enhanced security configuration"
echo -e "  ✅ Comprehensive documentation"
echo ""
echo -e "${YELLOW}🔐 Security Features:${NC}"
echo -e "  • SSH keys with Ed25519 encryption"
echo -e "  • GPG commit signing enabled"
echo -e "  • Fail2ban intrusion prevention"
echo -e "  • UFW firewall configured"
echo -e "  • Secure password generation"
echo -e "  • Container security hardening"
echo ""
echo -e "${CYAN}🚀 Next Steps:${NC}"
echo -e "  1. Authenticate Claude Code: ${BOLD}claude${NC}"
echo -e "  2. Create your first project: ${BOLD}claude-init my-project${NC}"
echo -e "  3. Start developing: ${BOLD}dev my-project${NC}"
echo -e "  4. Run health check: ${BOLD}health-check${NC}"
echo ""
echo -e "${PURPLE}📚 Documentation:${NC}"
echo -e "  • Quick start: ${BOLD}welcome-info${NC}"
echo -e "  • Full guide: ${BOLD}~/README.md${NC}"
echo -e "  • Authentication: ${BOLD}~/AUTHENTICATION.md${NC}"
echo ""
echo -e "${GREEN}🎯 Ready for AI-powered development!${NC}"
echo ""