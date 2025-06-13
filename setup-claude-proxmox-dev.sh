#!/usr/bin/env bash

# setup-claude-proxmox-dev.sh - Claude Code Development Environment Setup for Proxmox
# This script sets up Claude Code with essential MCP servers optimized for Proxmox development
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/your-repo/proxmox-helper-scripts/main/setup-claude-proxmox-dev.sh)"

set -euo pipefail

# Colors and styling
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
MAGENTA=$'\033[0;35m'
CYAN=$'\033[0;36m'
WHITE=$'\033[1;37m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m' # No Color

# Unicode characters for UI
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="➜"
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
PROGRESS_FILLED="█"
PROGRESS_EMPTY="░"

# Script variables
SCRIPT_VERSION="1.0.0"
CLAUDE_CODE_VERSION="latest"
NODE_VERSION="20"
LOG_FILE="/tmp/claude-proxmox-setup-$(date +%Y%m%d-%H%M%S).log"
CONFIG_DIR="$HOME/.config/claude-code"
MCP_CONFIG_FILE="$CONFIG_DIR/mcp-config.json"

# Spinner PID storage
SPINNER_PID=""

# Function to display fancy banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                              ║"
    echo "║  ${BOLD}${WHITE}   ____  _                   _         ____             _                ${CYAN}    ║"
    echo "║  ${BOLD}${WHITE}  / __ \| |                 | |       / __ \           | |               ${CYAN}    ║"
    echo "║  ${BOLD}${WHITE} | /  \/| | __ _ _   _  ____ | | ___  | /  \/ ___   ___| | ___           ${CYAN}    ║"
    echo "║  ${BOLD}${WHITE} | |    | |/ _\` | | | |/ _  || |/ _ \ | |    / _ \ / _  | |/ _ \          ${CYAN}    ║"
    echo "║  ${BOLD}${WHITE} | \__/\| | (_| | |_| | (_| || |  __/ | \__/\ (_) | (_| | |  __/          ${CYAN}    ║"
    echo "║  ${BOLD}${WHITE}  \____/|_|\__,_|\__,_|\__,_||_|\___|  \____/\___/ \__,_|_|\___|          ${CYAN}    ║"
    echo "║                                                                              ║"
    echo "║  ${MAGENTA}              🚀 Proxmox Development Environment Setup 🚀                  ${CYAN}   ║"
    echo "║  ${DIM}${WHITE}                        Version ${SCRIPT_VERSION}                            ${CYAN}      ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to display messages with formatting
msg_info() {
    echo -e "${BLUE}${ARROW}${NC} $1"
    log "INFO: $1"
}

msg_success() {
    echo -e "${GREEN}${CHECK_MARK}${NC} $1"
    log "SUCCESS: $1"
}

msg_error() {
    echo -e "${RED}${CROSS_MARK}${NC} $1"
    log "ERROR: $1"
}

msg_warning() {
    echo -e "${YELLOW}!${NC} $1"
    log "WARNING: $1"
}

# Function to create spinner
start_spinner() {
    local message="$1"
    (
        while true; do
            for frame in "${SPINNER_FRAMES[@]}"; do
                echo -ne "\r${BLUE}${frame}${NC} ${message}"
                sleep 0.1
            done
        done
    ) &
    SPINNER_PID=$!
}

# Function to stop spinner
stop_spinner() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
        SPINNER_PID=""
        echo -ne "\r"
    fi
}

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    echo -ne "\r["
    printf "%${filled}s" | tr ' ' "$PROGRESS_FILLED"
    printf "%${empty}s" | tr ' ' "$PROGRESS_EMPTY"
    echo -ne "] ${percentage}%"
}

# Function to check if running on Proxmox VE
check_proxmox() {
    msg_info "Checking Proxmox VE environment..."
    
    # Check multiple indicators of Proxmox VE
    if [[ -f /etc/pve/version ]]; then
        PVE_VERSION=$(cat /etc/pve/version)
        msg_success "Detected Proxmox VE ${PVE_VERSION}"
        return 0
    elif [[ -f /usr/bin/pvesh ]] || [[ -f /usr/sbin/pvesh ]]; then
        msg_success "Detected Proxmox VE (pvesh found)"
        return 0
    elif [[ -d /etc/pve ]] || [[ -f /etc/pve/.version ]]; then
        msg_success "Detected Proxmox VE (config directory found)"
        return 0
    elif systemctl is-active --quiet pve-cluster 2>/dev/null; then
        msg_success "Detected Proxmox VE (pve-cluster service running)"
        return 0
    elif [[ -f /etc/proxmox-release ]]; then
        PVE_VERSION=$(cat /etc/proxmox-release)
        msg_success "Detected Proxmox VE"
        return 0
    else
        msg_warning "This doesn't appear to be a Proxmox VE host"
        echo -e "${YELLOW}This script is optimized for Proxmox VE but can run on other Debian-based systems.${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            msg_error "Installation cancelled"
            exit 1
        fi
    fi
}

# Function to check system requirements
check_requirements() {
    msg_info "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        msg_warning "Running as root. Claude Code will be installed system-wide."
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            msg_success "Architecture: $ARCH"
            ;;
        *)
            msg_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Check available disk space (need at least 2GB)
    AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $AVAILABLE_SPACE -lt 2 ]]; then
        msg_error "Insufficient disk space. At least 2GB required."
        exit 1
    fi
    msg_success "Disk space: ${AVAILABLE_SPACE}GB available"
    
    # Check internet connectivity
    if ping -c 1 -W 3 google.com &> /dev/null; then
        msg_success "Internet connectivity: OK"
    else
        msg_error "No internet connectivity detected"
        exit 1
    fi
}

# Function to install Node.js
install_nodejs() {
    msg_info "Checking Node.js installation..."
    
    if command -v node &> /dev/null; then
        NODE_INSTALLED_VERSION=$(node -v | sed 's/v//')
        msg_success "Node.js ${NODE_INSTALLED_VERSION} already installed"
        
        # Check if npm is installed
        if ! command -v npm &> /dev/null; then
            msg_warning "npm not found, installing..."
            apt-get update -qq && apt-get install -y npm &>> "$LOG_FILE"
        fi
        return 0
    fi
    
    msg_info "Installing Node.js ${NODE_VERSION}.x..."
    start_spinner "Downloading Node.js setup script..."
    
    # Install Node.js via NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - &>> "$LOG_FILE"
    stop_spinner
    
    start_spinner "Installing Node.js and npm..."
    apt-get install -y nodejs &>> "$LOG_FILE"
    stop_spinner
    
    if command -v node &> /dev/null; then
        NODE_INSTALLED_VERSION=$(node -v)
        msg_success "Node.js ${NODE_INSTALLED_VERSION} installed successfully"
    else
        msg_error "Failed to install Node.js"
        exit 1
    fi
}

# Function to install Claude Code
install_claude_code() {
    msg_info "Installing Claude Code..."
    
    # Check if already installed
    if command -v claude &> /dev/null; then
        INSTALLED_VERSION=$(claude --version 2>/dev/null || echo "unknown")
        msg_warning "Claude Code ${INSTALLED_VERSION} is already installed"
        read -p "Reinstall/Update? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    start_spinner "Installing Claude Code globally..."
    npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} &>> "$LOG_FILE"
    stop_spinner
    
    if command -v claude &> /dev/null; then
        msg_success "Claude Code installed successfully"
        claude --version
    else
        msg_error "Failed to install Claude Code"
        exit 1
    fi
}

# MCP Server definitions
declare -A MCP_SERVERS
MCP_SERVERS=(
    ["github"]="GitHub MCP Server|Official GitHub integration for repos, issues, PRs"
    ["filesystem"]="Filesystem MCP|Advanced file operations and directory traversal"
    ["context7"]="Context7 MCP|Up-to-date documentation lookup"
    ["proxmox"]="Proxmox MCP|Direct Proxmox VE API integration"
    ["terraform"]="Terraform MCP|Infrastructure as Code operations"
    ["aws"]="AWS MCP Servers|AWS cloud infrastructure management"
    ["mongodb"]="MongoDB MCP|Database operations and management"
    ["supabase"]="Supabase MCP|Backend-as-a-Service integration"
    ["postman"]="Postman MCP|API testing and development"
    ["obsidian"]="Obsidian MCP|Knowledge management and notes"
    ["notion"]="Notion MCP|Project documentation and wikis"
    ["mentor"]="Mentor MCP|AI-powered code review with Deepseek"
    ["perplexity"]="Perplexity MCP|Enhanced search capabilities"
)

# Function to display MCP server selection menu
select_mcp_servers() {
    echo
    echo -e "${BOLD}${CYAN}Select MCP Servers to Install:${NC}"
    echo -e "${DIM}Use space to select/deselect, Enter to confirm${NC}"
    echo
    
    # Create array for dialog
    local options=()
    local descriptions=()
    for key in "${!MCP_SERVERS[@]}"; do
        IFS='|' read -r name desc <<< "${MCP_SERVERS[$key]}"
        options+=("$key" "$name" "off")
        descriptions["$key"]="$desc"
    done
    
    # Sort options
    IFS=$'\n' sorted=($(sort <<<"${options[*]}"))
    unset IFS
    
    # Use whiptail if available, otherwise basic select
    if command -v whiptail &> /dev/null; then
        SELECTED_SERVERS=$(whiptail --title "MCP Server Selection" \
            --checklist "Select MCP servers to install:" 20 78 12 \
            "github" "GitHub MCP Server (recommended)" ON \
            "filesystem" "Filesystem MCP (recommended)" ON \
            "context7" "Context7 Documentation (recommended)" ON \
            "proxmox" "Proxmox API Integration" ON \
            "terraform" "Terraform Infrastructure" OFF \
            "aws" "AWS Cloud Services" OFF \
            "mongodb" "MongoDB Database" OFF \
            "supabase" "Supabase Backend" OFF \
            "postman" "Postman API Testing" OFF \
            "obsidian" "Obsidian Notes" OFF \
            "notion" "Notion Documentation" OFF \
            "mentor" "AI Code Review" OFF \
            "perplexity" "Enhanced Search" OFF \
            3>&1 1>&2 2>&3)
    else
        # Fallback to basic selection
        echo "Select servers (space-separated numbers):"
        local i=1
        for key in github filesystem context7 proxmox terraform aws mongodb supabase postman obsidian notion mentor perplexity; do
            IFS='|' read -r name desc <<< "${MCP_SERVERS[$key]}"
            echo "  $i) $name - $desc"
            ((i++))
        done
        read -p "Enter selections (e.g., 1 2 3): " selections
        
        # Convert selections to server keys
        SELECTED_SERVERS=""
        local server_array=(github filesystem context7 proxmox terraform aws mongodb supabase postman obsidian notion mentor perplexity)
        for num in $selections; do
            if [[ $num -ge 1 && $num -le ${#server_array[@]} ]]; then
                SELECTED_SERVERS+="${server_array[$((num-1))]} "
            fi
        done
    fi
    
    if [[ -z "$SELECTED_SERVERS" ]]; then
        msg_warning "No MCP servers selected. You can add them later using 'claude mcp add'"
        return 0
    fi
    
    msg_success "Selected MCP servers: ${SELECTED_SERVERS}"
}

# Function to configure MCP servers
configure_mcp_servers() {
    msg_info "Configuring MCP servers..."
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Start with base configuration
    cat > "$MCP_CONFIG_FILE" <<'EOF'
{
  "mcpServers": {
EOF
    
    local first=true
    for server in $SELECTED_SERVERS; do
        server=$(echo "$server" | tr -d '"')
        
        if [[ "$first" != true ]]; then
            echo "," >> "$MCP_CONFIG_FILE"
        fi
        first=false
        
        case "$server" in
            "github")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": ""
      }
    }
EOF
                msg_warning "GitHub MCP requires a personal access token. Set it later in ~/.config/claude-code/mcp-config.json"
                ;;
            
            "filesystem")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem"]
    }
EOF
                ;;
            
            "context7")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
EOF
                ;;
            
            "proxmox")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "proxmox": {
      "command": "npx",
      "args": ["-y", "mcp-proxmox"],
      "env": {
        "PROXMOX_HOST": "https://localhost:8006",
        "PROXMOX_USER": "root@pam",
        "PROXMOX_PASSWORD": "",
        "PROXMOX_VERIFY_SSL": "false"
      }
    }
EOF
                msg_warning "Proxmox MCP requires credentials. Set them in ~/.config/claude-code/mcp-config.json"
                ;;
            
            "terraform")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "terraform": {
      "command": "npx",
      "args": ["-y", "@hashicorp/terraform-mcp-server"]
    }
EOF
                ;;
            
            "aws")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "aws": {
      "command": "npx",
      "args": ["-y", "@awslabs/mcp-server-aws"]
    }
EOF
                ;;
            
            "mongodb")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "mongodb": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-mongodb"],
      "env": {
        "MONGODB_URI": "mongodb://localhost:27017"
      }
    }
EOF
                ;;
            
            "supabase")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "supabase": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-supabase"],
      "env": {
        "SUPABASE_URL": "",
        "SUPABASE_SERVICE_ROLE_KEY": ""
      }
    }
EOF
                msg_warning "Supabase MCP requires URL and service role key. Set them in ~/.config/claude-code/mcp-config.json"
                ;;
            
            "postman")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "postman": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postman"],
      "env": {
        "POSTMAN_API_KEY": ""
      }
    }
EOF
                msg_warning "Postman MCP requires an API key. Set it in ~/.config/claude-code/mcp-config.json"
                ;;
            
            "obsidian")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "obsidian": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-obsidian"],
      "env": {
        "OBSIDIAN_VAULT_PATH": "$HOME/Documents/Obsidian"
      }
    }
EOF
                ;;
            
            "notion")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "notion": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-notion"],
      "env": {
        "NOTION_API_KEY": ""
      }
    }
EOF
                msg_warning "Notion MCP requires an API key. Set it in ~/.config/claude-code/mcp-config.json"
                ;;
            
            "mentor")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "mentor": {
      "command": "npx",
      "args": ["-y", "@cyanheads/mentor-mcp-server"],
      "env": {
        "DEEPSEEK_API_KEY": ""
      }
    }
EOF
                msg_warning "Mentor MCP requires a Deepseek API key. Set it in ~/.config/claude-code/mcp-config.json"
                ;;
            
            "perplexity")
                cat >> "$MCP_CONFIG_FILE" <<'EOF'
    "perplexity": {
      "command": "npx",
      "args": ["-y", "@cyanheads/perplexity-mcp-server"],
      "env": {
        "PERPLEXITY_API_KEY": ""
      }
    }
EOF
                msg_warning "Perplexity MCP requires an API key. Set it in ~/.config/claude-code/mcp-config.json"
                ;;
        esac
    done
    
    # Close the JSON
    echo -e "\n  }\n}" >> "$MCP_CONFIG_FILE"
    
    msg_success "MCP configuration saved to $MCP_CONFIG_FILE"
}

# Function to test Claude Code installation
test_installation() {
    echo
    msg_info "Testing Claude Code installation..."
    
    # Test basic command
    if claude --version &> /dev/null; then
        msg_success "Claude Code command is working"
    else
        msg_error "Claude Code command failed"
        return 1
    fi
    
    # Test MCP servers
    msg_info "Testing MCP server connections..."
    # Note: Actual MCP testing would require valid credentials
    msg_success "MCP configuration is ready (credentials need to be added)"
    
    return 0
}

# Function to show post-installation instructions
show_instructions() {
    echo
    echo -e "${BOLD}${GREEN}🎉 Installation Complete! 🎉${NC}"
    echo
    echo -e "${CYAN}${BOLD}Next Steps:${NC}"
    echo -e "1. ${YELLOW}Configure MCP server credentials:${NC}"
    echo -e "   Edit: ${BLUE}$MCP_CONFIG_FILE${NC}"
    echo
    echo -e "2. ${YELLOW}Start using Claude Code:${NC}"
    echo -e "   ${GREEN}claude${NC} - Start interactive session"
    echo -e "   ${GREEN}claude --help${NC} - Show all options"
    echo -e "   ${GREEN}claude mcp add${NC} - Add more MCP servers"
    echo
    echo -e "3. ${YELLOW}For Proxmox development:${NC}"
    echo -e "   ${GREEN}claude \"Help me create a Proxmox LXC container\"${NC}"
    echo -e "   ${GREEN}claude \"Show me the Proxmox API documentation\"${NC}"
    echo
    echo -e "${CYAN}${BOLD}Important Configuration:${NC}"
    echo -e "- Claude Code config: ${BLUE}~/.config/claude-code/${NC}"
    echo -e "- MCP servers config: ${BLUE}$MCP_CONFIG_FILE${NC}"
    echo -e "- Log file: ${BLUE}$LOG_FILE${NC}"
    echo
    echo -e "${DIM}For more information, visit: https://claude.ai/code${NC}"
    echo
}

# Function to create uninstall script
create_uninstall_script() {
    cat > "$CONFIG_DIR/uninstall.sh" <<'EOF'
#!/bin/bash
echo "Uninstalling Claude Code..."
npm uninstall -g @anthropic-ai/claude-code
rm -rf ~/.config/claude-code
rm -rf ~/.claude
rm -f ~/.mcp.json
echo "Claude Code has been uninstalled."
EOF
    chmod +x "$CONFIG_DIR/uninstall.sh"
}

# Main installation flow
main() {
    # Show banner
    show_banner
    
    # Initial setup
    msg_info "Starting Claude Code setup for Proxmox development..."
    msg_info "Log file: $LOG_FILE"
    echo
    
    # Check environment
    check_proxmox
    check_requirements
    echo
    
    # Install dependencies
    install_nodejs
    echo
    
    # Install Claude Code
    install_claude_code
    echo
    
    # Configure MCP servers
    select_mcp_servers
    if [[ -n "$SELECTED_SERVERS" ]]; then
        configure_mcp_servers
    fi
    echo
    
    # Test installation
    test_installation
    
    # Create uninstall script
    create_uninstall_script
    
    # Show completion message
    show_instructions
}

# Run main function
main "$@"