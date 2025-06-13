#!/usr/bin/env bash

# setup-claude-dev-env.sh - Universal Claude Code Development Environment Setup
# This script creates isolated Claude Code development environments with optional containerization
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/your-repo/proxmox-helper-scripts/main/setup-claude-dev-env.sh)"

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
LOG_FILE="/tmp/claude-dev-env-setup-$(date +%Y%m%d-%H%M%S).log"
CONFIG_DIR="$HOME/.config/claude-code"
MCP_CONFIG_FILE="$CONFIG_DIR/mcp-config.json"

# Spinner PID storage
SPINNER_PID=""

# Function to display fancy banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╭─────────────────────────────────────────────────────╮"
    echo "│                                                     │"
    echo "│  ${WHITE}🤖 Claude Code Development Environment Setup  ${CYAN}│"
    echo "│  ${DIM}${WHITE}Fast • Secure • Containerized                 ${CYAN}│"
    echo "│  ${DIM}${WHITE}Version ${SCRIPT_VERSION}                                 ${CYAN}│"
    echo "│                                                     │"
    echo "╰─────────────────────────────────────────────────────╯"
    echo -e "${NC}"
    echo
}

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to display messages with formatting
msg_info() {
    echo -e "${BLUE}ℹ️  ${NC}$1"
    log "INFO: $1"
}

msg_success() {
    echo -e "${GREEN}✅ ${NC}$1"
    log "SUCCESS: $1"
}

msg_error() {
    echo -e "${RED}❌ ${NC}$1"
    log "ERROR: $1"
}

msg_warning() {
    echo -e "${YELLOW}⚠️  ${NC}$1"
    log "WARNING: $1"
}

msg_step() {
    echo -e "${CYAN}🔄 ${NC}$1"
    log "STEP: $1"
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

# Environment detection variables
IS_PROXMOX=false
HAS_DOCKER=false
ENVIRONMENT_TYPE=""
PROJECT_MODE=""

# SSH configuration variables
SSH_AUTH_METHOD=""
SSH_PUBLIC_KEY=""
SSH_PASSWORD=""
SSH_PORT=""
CONTAINER_IP_CONFIG=""

# Storage configuration
SELECTED_STORAGE=""

# Function to detect available environments
detect_environments() {
    msg_step "Environment discovery"
    
    local detected=()
    
    # Check for Proxmox VE
    if [[ -f /etc/pve/version ]] || [[ -f /usr/bin/pvesh ]] || [[ -f /usr/sbin/pvesh ]] || \
       [[ -d /etc/pve ]] || (systemctl is-active --quiet pve-cluster 2>/dev/null || true) || \
       [[ -f /etc/proxmox-release ]]; then
        IS_PROXMOX=true
        if [[ -f /etc/pve/version ]]; then
            PVE_VERSION=$(cat /etc/pve/version 2>/dev/null || echo "unknown")
            detected+=("📦 Proxmox VE $PVE_VERSION")
        else
            detected+=("📦 Proxmox VE")
        fi
    fi
    
    # Check for Docker
    if command -v docker &> /dev/null && (docker info &> /dev/null || true); then
        HAS_DOCKER=true
        DOCKER_VERSION=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo "unknown")
        detected+=("🐳 Docker $DOCKER_VERSION")
    fi
    
    # Always available
    detected+=("💻 Local system")
    
    if [[ ${#detected[@]} -eq 1 ]]; then
        msg_success "Available: ${detected[0]}"
    else
        echo -e "${GREEN}✅ Detected environments:${NC}"
        for env in "${detected[@]}"; do
            echo -e "  $env"
        done
    fi
}

# Function to display modern interactive menu
show_menu() {
    local title="$1"
    local subtitle="$2"
    shift 2
    local options=("$@")
    
    echo
    echo -e "${CYAN}${BOLD}$title${NC}"
    if [[ -n "$subtitle" ]]; then
        echo -e "${DIM}$subtitle${NC}"
    fi
    echo
    
    for option in "${options[@]}"; do
        echo -e "$option"
    done
    echo
}

# Function to display environment selection menu
select_environment() {
    local options=()
    local env_types=()
    local menu_items=()
    
    # Always offer local installation
    options+=("1")
    env_types+=("local")
    menu_items+=("${CYAN}💻 [1]${NC} ${WHITE}Local Installation${NC} ${DIM}(install on current system)${NC}")
    
    # Add Proxmox option if available
    if [[ "$IS_PROXMOX" == "true" ]]; then
        local next_num=$((${#options[@]} + 1))
        options+=("$next_num")
        env_types+=("proxmox")
        menu_items+=("${GREEN}📦 [$next_num]${NC} ${WHITE}Proxmox LXC Container${NC} ${DIM}(isolated environment)${NC}")
    fi
    
    # Add Docker option if available
    if [[ "$HAS_DOCKER" == "true" ]]; then
        local next_num=$((${#options[@]} + 1))
        options+=("$next_num")
        env_types+=("docker")
        menu_items+=("${BLUE}🐳 [$next_num]${NC} ${WHITE}Docker Container${NC} ${DIM}(portable environment)${NC}")
    fi
    
    show_menu "🚀 Choose Development Environment" "Select where you want to install Claude Code" "${menu_items[@]}"
    
    # Check if running interactively
    if [[ ! -t 0 ]]; then
        # Non-interactive mode - use default (local)
        choice=1
        msg_info "Non-interactive mode: Using default local installation"
    else
        # Interactive mode
        while true; do
            read -p "$(echo -e "${BOLD}Enter your choice [1]:${NC} ")" choice
            choice=${choice:-1}
            
            # Validate choice
            local found=false
            for i in "${!options[@]}"; do
                if [[ "${options[i]}" == "$choice" ]]; then
                    found=true
                    break
                fi
            done
            
            if [[ "$found" == "true" ]]; then
                break
            else
                msg_error "Invalid choice. Please enter a number from the menu."
            fi
        done
    fi
    
    # Set environment type based on choice
    for i in "${!options[@]}"; do
        if [[ "${options[i]}" == "$choice" ]]; then
            ENVIRONMENT_TYPE="${env_types[i]}"
            break
        fi
    done
    
    local env_icon=""
    case "$ENVIRONMENT_TYPE" in
        "local") env_icon="💻" ;;
        "proxmox") env_icon="📦" ;;
        "docker") env_icon="🐳" ;;
    esac
    msg_success "Selected: $env_icon $ENVIRONMENT_TYPE environment"
}

# Function to display project mode selection
select_project_mode() {
    local menu_items=(
        "${GREEN}📁 [1]${NC} ${WHITE}New Project${NC} ${DIM}(create fresh project directory)${NC}"
        "${BLUE}📥 [2]${NC} ${WHITE}Clone Repository${NC} ${DIM}(git clone existing project)${NC}"
        "${YELLOW}📂 [3]${NC} ${WHITE}Current Directory${NC} ${DIM}(use $(basename "$PWD"))${NC}"
    )
    
    show_menu "📋 Choose Project Setup" "How do you want to set up your project?" "${menu_items[@]}"
    
    # Check if running interactively
    if [[ ! -t 0 ]]; then
        # Non-interactive mode - use default (current directory)
        choice=3
        msg_info "Non-interactive mode: Using current directory"
    else
        # Interactive mode
        while true; do
            read -p "$(echo -e "${BOLD}Enter your choice [3]:${NC} ")" choice
            choice=${choice:-3}
            
            case $choice in
                1|2|3) break ;;
                *) msg_error "Invalid choice. Please enter 1, 2, or 3." ;;
            esac
        done
    fi
    
    case $choice in
        1) 
            PROJECT_MODE="new"
            msg_success "Selected: 📁 New project setup"
            ;;
        2) 
            PROJECT_MODE="clone"
            msg_success "Selected: 📥 Clone existing repository"
            ;;
        3) 
            PROJECT_MODE="current"
            msg_success "Selected: 📂 Use current directory"
            ;;
    esac
}

# Function to show installation progress
show_progress_step() {
    local step=$1
    local total=$2
    local description=$3
    
    local percentage=$((step * 100 / total))
    echo -e "${CYAN}[$step/$total] ${description}${NC}"
}

# Function to check system requirements
check_requirements() {
    msg_step "System compatibility check"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}ℹ️  Running as root - will install system-wide${NC}"
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64) 
            echo -e "${GREEN}✅ Architecture: $ARCH${NC}"
            ;;
        *)
            msg_error "Unsupported architecture: $ARCH (need x86_64/amd64)"
            exit 1
            ;;
    esac
    
    # Check available disk space
    AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")
    if [[ $AVAILABLE_SPACE -lt 2 ]]; then
        msg_error "Need at least 2GB disk space (${AVAILABLE_SPACE}GB available)"
        exit 1
    fi
    echo -e "${GREEN}✅ Disk space: ${AVAILABLE_SPACE}GB available${NC}"
    
    # Check internet connectivity
    if ! ping -c 1 -W 3 google.com &> /dev/null; then
        msg_error "No internet connection detected"
        exit 1
    fi
    echo -e "${GREEN}✅ Internet connectivity OK${NC}"
    
    msg_success "System ready for installation"
}

# Function to install Node.js
install_nodejs() {
    msg_step "Setting up Node.js runtime"
    
    if command -v node &> /dev/null; then
        NODE_INSTALLED_VERSION=$(node -v | sed 's/v//')
        msg_success "Node.js $NODE_INSTALLED_VERSION detected"
        
        # Ensure npm is available
        if ! command -v npm &> /dev/null; then
            echo -ne "${BLUE}Installing npm...${NC}"
            apt-get update -qq && apt-get install -y npm &>> "$LOG_FILE"
            echo -e "\r${GREEN}✅ npm installed${NC}"
        fi
        return 0
    fi
    
    echo -e "${BLUE}📦 Installing Node.js ${NODE_VERSION}.x...${NC}"
    
    # Install Node.js with minimal output
    if curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - &>> "$LOG_FILE" && \
       apt-get install -y nodejs &>> "$LOG_FILE"; then
        NODE_INSTALLED_VERSION=$(node -v)
        msg_success "Node.js $NODE_INSTALLED_VERSION ready"
    else
        msg_error "Node.js installation failed (check $LOG_FILE)"
        exit 1
    fi
}

# Function to install Claude Code
install_claude_code() {
    msg_step "Installing Claude Code CLI"
    
    # Check if already installed
    if command -v claude &> /dev/null; then
        INSTALLED_VERSION=$(claude --version 2>/dev/null | head -1 || echo "unknown")
        echo -e "${YELLOW}⚠️  Claude Code already installed: $INSTALLED_VERSION${NC}"
        
        if [[ ! -t 0 ]]; then
            # Non-interactive mode - use existing installation
            msg_success "Using existing Claude Code installation"
            return 0
        else
            # Interactive mode - ask user
            read -p "$(echo -e "${BOLD}Update to latest version? (y/N):${NC} ")" -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                msg_success "Using existing Claude Code installation"
                return 0
            fi
        fi
    fi
    
    echo -e "${BLUE}🚀 Installing Claude Code CLI...${NC}"
    if npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} &>> "$LOG_FILE"; then
        INSTALLED_VERSION=$(claude --version 2>/dev/null | head -1 || echo "installed")
        msg_success "Claude Code ready: $INSTALLED_VERSION"
    else
        msg_error "Claude Code installation failed (check $LOG_FILE)"
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
    echo -e "${CYAN}${BOLD}🔧 MCP Server Selection${NC}"
    echo -e "${DIM}Choose integrations for your Claude Code environment${NC}"
    echo
    
    echo -e "${GREEN}${BOLD}📦 Recommended (auto-selected):${NC}"
    echo -e "  ${GREEN}✓${NC} GitHub Integration ${DIM}(repos, issues, PRs)${NC}"
    echo -e "  ${GREEN}✓${NC} Filesystem Operations ${DIM}(file management)${NC}"  
    echo -e "  ${GREEN}✓${NC} Context7 Documentation ${DIM}(up-to-date docs)${NC}"
    
    if [[ "$IS_PROXMOX" == "true" ]]; then
        echo -e "  ${GREEN}✓${NC} Proxmox Integration ${DIM}(VM/container management)${NC}"
    fi
    echo
    
    echo -e "${YELLOW}${BOLD}⚡ Optional Integrations:${NC}"
    echo -e "  ${CYAN}[1]${NC} AWS Cloud Services ${DIM}(EC2, S3, etc.)${NC}"
    echo -e "  ${CYAN}[2]${NC} Terraform Infrastructure ${DIM}(IaC automation)${NC}"
    echo -e "  ${CYAN}[3]${NC} MongoDB Database ${DIM}(NoSQL operations)${NC}"
    echo -e "  ${CYAN}[4]${NC} Supabase Backend ${DIM}(BaaS integration)${NC}"
    echo -e "  ${CYAN}[5]${NC} AI Code Review ${DIM}(Deepseek mentor)${NC}"
    echo -e "  ${CYAN}[6]${NC} Enhanced Search ${DIM}(Perplexity API)${NC}"
    echo
    
    # Auto-select recommended servers
    SELECTED_SERVERS="github filesystem context7"
    if [[ "$IS_PROXMOX" == "true" ]]; then
        SELECTED_SERVERS+=" proxmox"
    fi
    
    if [[ ! -t 0 ]]; then
        # Non-interactive mode - skip optional integrations
        optional_choices=""
        msg_info "Non-interactive mode: Using recommended integrations only"
    else
        # Interactive mode
        read -p "$(echo -e "${BOLD}Add optional integrations? (enter numbers like '1 5 6', or press Enter to skip):${NC} ")" optional_choices
    fi
    
    if [[ -n "$optional_choices" ]]; then
        for choice in $optional_choices; do
            case $choice in
                1) SELECTED_SERVERS+=" aws" ;;
                2) SELECTED_SERVERS+=" terraform" ;;
                3) SELECTED_SERVERS+=" mongodb" ;;
                4) SELECTED_SERVERS+=" supabase" ;;
                5) SELECTED_SERVERS+=" mentor" ;;
                6) SELECTED_SERVERS+=" perplexity" ;;
                *) msg_warning "Unknown option: $choice" ;;
            esac
        done
    fi
    
    # Count selected servers
    local server_count=$(echo $SELECTED_SERVERS | wc -w)
    msg_success "Selected $server_count MCP integrations: $SELECTED_SERVERS"
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

# Function to select storage pool
select_storage_pool() {
    msg_info "Selecting storage pool..."
    
    # Debug: Add trap to catch exit
    trap 'msg_error "Storage selection function exited unexpectedly at line $LINENO"' ERR
    
    # Debug: Test basic pvesh command
    msg_info "Testing pvesh command availability..."
    if ! command -v pvesh &> /dev/null; then
        msg_error "pvesh command not found"
        SELECTED_STORAGE="local-lvm"
        msg_warning "Using default storage: $SELECTED_STORAGE"
        trap - ERR
        return 0
    fi
    
    # Get available storage pools with error handling
    local storage_list=""
    
    # Use the working method we discovered
    msg_info "Querying storage pools..."
    storage_list=$(pvesh get /storage 2>/dev/null | grep -o '[a-zA-Z][a-zA-Z0-9_-]*' | grep -v storage || true)
    
    # Final fallback to common storage names
    if [[ -z "$storage_list" ]]; then
        msg_warning "Could not detect storage pools, using common defaults"
        storage_list="local-lvm local"
    fi
    
    msg_info "Storage candidates found: $storage_list"
    
    # Convert to array for easier handling
    local storage_array=()
    if [[ -n "$storage_list" ]]; then
        # Use a more robust method to convert to array
        IFS=$'\n' read -d '' -r -a storage_array <<< "$storage_list" || true
        
        # Debug: show what we found
        for storage in "${storage_array[@]}"; do
            if [[ -n "$storage" ]]; then
                msg_info "Added storage: $storage"
            fi
        done
    fi
    
    msg_info "Total storage pools found: ${#storage_array[@]}"
    
    if [[ ${#storage_array[@]} -eq 0 ]]; then
        msg_error "No suitable storage pools found after parsing"
        SELECTED_STORAGE="local-lvm"
        msg_warning "Using default storage: $SELECTED_STORAGE"
        trap - ERR
        return 0
    fi
    
    # If only one storage available, use it automatically
    if [[ ${#storage_array[@]} -eq 1 ]]; then
        SELECTED_STORAGE="${storage_array[0]}"
        msg_success "Using available storage: $SELECTED_STORAGE"
        trap - ERR
        return 0
    fi
    
    # Multiple storage options - let user choose
    echo
    echo "Available storage pools:"
    for i in "${!storage_array[@]}"; do
        echo "  $((i+1))) ${storage_array[i]}"
    done
    echo
    
    while true; do
        read -p "Select storage pool [1]: " storage_choice
        storage_choice=${storage_choice:-1}
        
        if [[ "$storage_choice" =~ ^[0-9]+$ ]] && [[ "$storage_choice" -ge 1 ]] && [[ "$storage_choice" -le "${#storage_array[@]}" ]]; then
            SELECTED_STORAGE="${storage_array[$((storage_choice-1))]}"
            msg_success "Selected storage: $SELECTED_STORAGE"
            break
        else
            msg_error "Invalid choice. Please enter a number between 1 and ${#storage_array[@]}"
        fi
    done
    
    # Clear the error trap
    trap - ERR
}

# Function to gather SSH configuration
gather_ssh_config() {
    echo
    msg_info "SSH Configuration Setup"
    echo
    
    # SSH Key or Password
    echo "Choose SSH authentication method:"
    echo "1) SSH Key (recommended)"
    echo "2) Password authentication"
    read -p "Enter choice [1]: " ssh_choice
    ssh_choice=${ssh_choice:-1}
    
    case $ssh_choice in
        1)
            SSH_AUTH_METHOD="key"
            echo
            echo "SSH Key Setup Options:"
            echo "1) Use existing SSH key from ~/.ssh/id_rsa.pub"
            echo "2) Provide SSH key manually"
            echo
            echo -e "${CYAN}💡 Tip: Find your SSH key on your local machine:${NC}"
            echo -e "   ${DIM}Linux/macOS:${NC} ls ~/.ssh/*.pub"
            echo -e "   ${DIM}Windows:${NC}    dir %USERPROFILE%\\.ssh\\*.pub"
            echo -e "   ${DIM}Copy key:${NC}    cat ~/.ssh/id_rsa.pub (Linux) or type %USERPROFILE%\\.ssh\\id_rsa.pub (Windows)"
            echo
            read -p "Enter choice [1]: " key_choice
            key_choice=${key_choice:-1}
            
            case $key_choice in
                1)
                    if [[ -f /root/.ssh/id_rsa.pub ]]; then
                        SSH_PUBLIC_KEY=$(cat /root/.ssh/id_rsa.pub)
                        msg_success "Using SSH key from /root/.ssh/id_rsa.pub"
                    elif [[ -f /root/.ssh/id_ed25519.pub ]]; then
                        SSH_PUBLIC_KEY=$(cat /root/.ssh/id_ed25519.pub)
                        msg_success "Using SSH key from /root/.ssh/id_ed25519.pub"
                    else
                        msg_warning "No SSH key found in /root/.ssh/"
                        echo
                        echo -e "${YELLOW}🔑 Generate a new SSH key on your local machine:${NC}"
                        echo -e "   ${DIM}Command:${NC} ssh-keygen -t rsa -b 4096 -C \"your_email@example.com\""
                        echo -e "   ${DIM}Then run:${NC} cat ~/.ssh/id_rsa.pub (Linux/macOS) or type %USERPROFILE%\\.ssh\\id_rsa.pub (Windows)"
                        echo
                        echo "Please paste your SSH public key:"
                        read -r SSH_PUBLIC_KEY
                    fi
                    ;;
                2)
                    echo
                    echo -e "${YELLOW}📋 How to copy your SSH public key:${NC}"
                    echo -e "   ${DIM}Linux/macOS:${NC} cat ~/.ssh/id_rsa.pub | pbcopy (macOS) or cat ~/.ssh/id_rsa.pub | xclip -selection clipboard (Linux)"
                    echo -e "   ${DIM}Windows:${NC}    type %USERPROFILE%\\.ssh\\id_rsa.pub | clip"
                    echo
                    echo "Please paste your SSH public key:"
                    read -r SSH_PUBLIC_KEY
                    ;;
            esac
            ;;
        2)
            SSH_AUTH_METHOD="password"
            while true; do
                read -s -p "Enter password for root user: " ssh_password
                echo
                read -s -p "Confirm password: " ssh_password_confirm
                echo
                if [[ "$ssh_password" == "$ssh_password_confirm" ]]; then
                    SSH_PASSWORD="$ssh_password"
                    break
                else
                    msg_error "Passwords don't match. Please try again."
                fi
            done
            ;;
    esac
    
    # SSH Port
    read -p "SSH port [22]: " ssh_port
    SSH_PORT=${ssh_port:-22}
    
    # Container IP configuration
    echo
    echo "Container network configuration:"
    echo "1) DHCP (automatic IP)"
    echo "2) Static IP"
    read -p "Enter choice [1]: " ip_choice
    ip_choice=${ip_choice:-1}
    
    case $ip_choice in
        1)
            CONTAINER_IP_CONFIG="ip=dhcp"
            msg_info "Container will use DHCP"
            ;;
        2)
            read -p "Enter static IP (e.g., 192.168.1.100/24): " static_ip
            read -p "Enter gateway IP (e.g., 192.168.1.1): " gateway_ip
            CONTAINER_IP_CONFIG="ip=${static_ip},gw=${gateway_ip}"
            msg_info "Container will use static IP: $static_ip"
            ;;
    esac
    
    msg_info "DEBUG: SSH_AUTH_METHOD='${SSH_AUTH_METHOD}'"
    msg_info "DEBUG: SSH_PUBLIC_KEY length: ${#SSH_PUBLIC_KEY}"
    msg_info "DEBUG: CONTAINER_IP_CONFIG='${CONTAINER_IP_CONFIG}'"
}

# Function to create Proxmox LXC container
create_proxmox_container() {
    msg_info "Creating Proxmox LXC container for Claude Code development..."
    
    # Select storage pool
    select_storage_pool
    
    # Gather SSH configuration
    gather_ssh_config
    
    # Get next available container ID
    local vmid
    vmid=$(pvesh get /cluster/nextid 2>/dev/null || echo "100")
    
    # Container configuration
    local hostname="claude-dev-${vmid}"
    local template=""
    local template_file=""
    
    # Find available Ubuntu template
    msg_info "Finding available Ubuntu template..."
    pveam update
    
    # List available templates and find Ubuntu
    msg_info "Checking available templates..."
    local template_list
    template_list=$(pveam available --section system 2>/dev/null | grep -i ubuntu | head -5)
    
    if [[ -z "$template_list" ]]; then
        msg_error "No Ubuntu templates found in repository"
        msg_info "Available templates:"
        pveam available --section system | head -10
        exit 1
    fi
    
    # Try common Ubuntu template patterns
    local template_candidates=(
        "ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
        "ubuntu-20.04-standard_20.04.1-1_amd64.tar.gz"
        "ubuntu-22.04-standard_22.04-1_amd64.tar.gz"
        "ubuntu-20.04-standard_20.04-1_amd64.tar.gz"
    )
    
    for candidate in "${template_candidates[@]}"; do
        if echo "$template_list" | grep -q "$candidate"; then
            template_file="$candidate"
            break
        fi
    done
    
    # If no specific match, use the first Ubuntu template found
    if [[ -z "$template_file" ]]; then
        template_file=$(echo "$template_list" | head -1 | awk '{print $2}')
        if [[ -z "$template_file" ]]; then
            msg_error "Could not parse template name from available list"
            msg_info "Available Ubuntu templates:"
            echo "$template_list"
            exit 1
        fi
    fi
    
    template="local:vztmpl/${template_file}"
    msg_success "Selected template: ${template_file}"
    
    # Check if template exists locally, download if needed
    if ! [[ -f "/var/lib/vz/template/cache/${template_file}" ]]; then
        msg_info "Downloading LXC template: ${template_file}"
        if ! pveam download local "$template_file"; then
            msg_error "Failed to download template: ${template_file}"
            exit 1
        fi
    else
        msg_success "Template already available: ${template_file}"
    fi
    
    # Create container
    msg_info "Creating container ${vmid} with hostname ${hostname}..."
    msg_info "Storage: ${SELECTED_STORAGE}"
    msg_info "Network config: name=eth0,bridge=vmbr0,${CONTAINER_IP_CONFIG}"
    
    # Try container creation with proper error handling
    if ! pct create "$vmid" "$template" \
        --cores 2 \
        --hostname "$hostname" \
        --memory 2048 \
        --swap 1024 \
        --net0 "name=eth0,bridge=vmbr0,${CONTAINER_IP_CONFIG}" \
        --storage "$SELECTED_STORAGE" \
        --rootfs "${SELECTED_STORAGE}:8" \
        --unprivileged 1 \
        --features keyctl=1,nesting=1,fuse=1 \
        --ostype ubuntu \
        --start 1 \
        --onboot 0; then
        msg_error "Failed to create container"
        msg_info "Trying with simpler network configuration..."
        
        # Fallback: try with basic DHCP config
        if ! pct create "$vmid" "$template" \
            --cores 2 \
            --hostname "$hostname" \
            --memory 2048 \
            --swap 1024 \
            --net0 "name=eth0,bridge=vmbr0,ip=dhcp" \
            --storage "$SELECTED_STORAGE" \
            --rootfs "${SELECTED_STORAGE}:8" \
            --unprivileged 1 \
            --features keyctl=1,nesting=1,fuse=1 \
            --ostype ubuntu \
            --start 1 \
            --onboot 0; then
            msg_error "Container creation failed completely"
            exit 1
        fi
    fi
    
    # Wait for container to start
    msg_info "Waiting for container to start..."
    sleep 10
    
    # Update and install basic packages
    msg_info "Setting up container environment..."
    pct exec "$vmid" -- apt-get update
    pct exec "$vmid" -- apt-get install -y curl wget git sudo whiptail openssh-server
    
    # Configure SSH
    msg_info "Configuring SSH access..."
    pct exec "$vmid" -- systemctl enable ssh
    pct exec "$vmid" -- systemctl start ssh
    
    # Configure SSH port if not default
    if [[ "$SSH_PORT" != "22" ]]; then
        pct exec "$vmid" -- sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
        pct exec "$vmid" -- systemctl restart ssh
    fi
    
    # Setup authentication
    case "$SSH_AUTH_METHOD" in
        "key")
            msg_info "Setting up SSH key authentication..."
            pct exec "$vmid" -- mkdir -p /root/.ssh
            pct exec "$vmid" -- bash -c "echo '$SSH_PUBLIC_KEY' > /root/.ssh/authorized_keys"
            pct exec "$vmid" -- chmod 600 /root/.ssh/authorized_keys
            pct exec "$vmid" -- chmod 700 /root/.ssh
            pct exec "$vmid" -- sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
            pct exec "$vmid" -- systemctl restart ssh
            ;;
        "password")
            msg_info "Setting up password authentication..."
            pct exec "$vmid" -- bash -c "echo 'root:$SSH_PASSWORD' | chpasswd"
            pct exec "$vmid" -- sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
            pct exec "$vmid" -- systemctl restart ssh
            ;;
    esac
    
    # Install Node.js and Claude Code inside container
    msg_info "Installing Node.js in container..."
    pct exec "$vmid" -- bash -c "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
    pct exec "$vmid" -- apt-get install -y nodejs
    
    msg_info "Installing Claude Code in container..."
    pct exec "$vmid" -- npm install -g @anthropic-ai/claude-code
    
    # Setup project directory based on mode
    setup_project_in_container "$vmid"
    
    # Get container IP address
    local container_ip
    container_ip=$(pct exec "$vmid" -- hostname -I | awk '{print $1}')
    
    msg_success "Proxmox container ${vmid} created successfully!"
    echo
    msg_info "Development environment ready!"
    echo
    msg_info "SSH Access Information:"
    if [[ "$SSH_AUTH_METHOD" == "key" ]]; then
        echo "  ssh root@${container_ip} -p ${SSH_PORT}"
        msg_info "SSH key authentication configured"
    else
        echo "  ssh root@${container_ip} -p ${SSH_PORT}"
        msg_info "Password authentication configured"
    fi
    echo
    msg_info "Alternative access methods:"
    echo "  Proxmox console: pct enter ${vmid}"
    echo "  Project directory: /opt/project"
    echo "  Start Claude Code: claude"
    echo
    msg_info "Container Details:"
    echo "  Container ID: ${vmid}"
    echo "  Hostname: ${hostname}"
    echo "  IP Address: ${container_ip}"
    echo "  SSH Port: ${SSH_PORT}"
}

# Function to create Docker container
create_docker_container() {
    msg_info "Creating Docker container for Claude Code development..."
    
    local container_name="claude-dev-$(date +%s)"
    local image="ubuntu:22.04"
    
    # Create and start container
    msg_info "Starting Docker container..."
    docker run -d --name "$container_name" \
        -v "/tmp:/tmp" \
        -w "/opt/project" \
        "$image" \
        tail -f /dev/null
    
    # Install dependencies
    msg_info "Setting up container environment..."
    docker exec "$container_name" apt-get update
    docker exec "$container_name" apt-get install -y curl wget git sudo nodejs npm
    
    # Install Claude Code
    msg_info "Installing Claude Code in container..."
    docker exec "$container_name" npm install -g @anthropic-ai/claude-code
    
    # Setup project based on mode
    setup_project_in_container "$container_name" "docker"
    
    msg_success "Docker container ${container_name} created successfully!"
    echo
    msg_info "Access your development environment:"
    echo "  docker exec -it ${container_name} bash"
    echo "  cd /opt/project"
    echo "  claude"
}

# Function to setup project in container
setup_project_in_container() {
    local container_id="$1"
    local container_type="${2:-proxmox}"
    
    case "$PROJECT_MODE" in
        "new")
            if [[ "$container_type" == "docker" ]]; then
                docker exec "$container_id" mkdir -p /opt/project
            else
                pct exec "$container_id" -- mkdir -p /opt/project
            fi
            msg_success "New project directory created in container"
            ;;
        "clone")
            read -p "Enter Git repository URL: " repo_url
            if [[ -n "$repo_url" ]]; then
                if [[ "$container_type" == "docker" ]]; then
                    docker exec "$container_id" bash -c "cd /opt && git clone '$repo_url' project"
                else
                    pct exec "$container_id" -- bash -c "cd /opt && git clone '$repo_url' project"
                fi
                msg_success "Repository cloned in container"
            fi
            ;;
        "current")
            # Copy current directory to container
            local temp_archive="/tmp/project-$(date +%s).tar.gz"
            tar -czf "$temp_archive" -C "$(dirname "$PWD")" "$(basename "$PWD")"
            
            if [[ "$container_type" == "docker" ]]; then
                docker cp "$temp_archive" "$container_id:/tmp/"
                docker exec "$container_id" bash -c "cd /opt && tar -xzf /tmp/$(basename "$temp_archive") && mv '$(basename "$PWD")' project"
            else
                pct push "$container_id" "$temp_archive" "/tmp/$(basename "$temp_archive")"
                pct exec "$container_id" -- bash -c "cd /opt && tar -xzf /tmp/$(basename "$temp_archive") && mv '$(basename "$PWD")' project"
            fi
            
            rm -f "$temp_archive"
            msg_success "Current project copied to container"
            ;;
    esac
}

# Function to setup local project
setup_local_project() {
    case "$PROJECT_MODE" in
        "new")
            read -p "Enter project name [claude-project]: " project_name
            project_name=${project_name:-claude-project}
            mkdir -p "$project_name"
            cd "$project_name"
            msg_success "New project directory created: $project_name"
            ;;
        "clone")
            read -p "Enter Git repository URL: " repo_url
            if [[ -n "$repo_url" ]]; then
                git clone "$repo_url"
                local repo_name=$(basename "$repo_url" .git)
                cd "$repo_name"
                msg_success "Repository cloned: $repo_name"
            fi
            ;;
        "current")
            msg_success "Using current directory: $(pwd)"
            ;;
    esac
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
    echo -e "${GREEN}${BOLD}🎉 Claude Code Environment Ready!${NC}"
    echo
    
    # Quick start section
    echo -e "${CYAN}${BOLD}🚀 Quick Start:${NC}"
    echo -e "  ${GREEN}claude${NC}                    ${DIM}# Start Claude Code${NC}"
    echo -e "  ${GREEN}claude --help${NC}             ${DIM}# Show available options${NC}"
    echo
    
    # Configuration section (only if servers were selected)
    if [[ -n "$SELECTED_SERVERS" ]]; then
        echo -e "${YELLOW}${BOLD}⚙️  Next: Configure API Keys${NC}"
        echo -e "  ${BLUE}$MCP_CONFIG_FILE${NC}"
        echo -e "  ${DIM}# Add your API tokens for selected integrations${NC}"
        echo
    fi
    
    # Environment-specific info
    if [[ "$ENVIRONMENT_TYPE" != "local" ]]; then
        echo -e "${MAGENTA}${BOLD}📦 Container Access:${NC}"
        if [[ "$ENVIRONMENT_TYPE" == "proxmox" ]]; then
            echo -e "  ${GREEN}pct enter ${VMID:-<container-id>}${NC}    ${DIM}# Direct console access${NC}"
            echo -e "  ${GREEN}ssh root@<container-ip>${NC}        ${DIM}# Remote SSH access${NC}"
        else
            echo -e "  ${GREEN}docker exec -it <container> bash${NC} ${DIM}# Access container${NC}"
        fi
        echo
    fi
    
    echo -e "${DIM}📚 Documentation: ${BLUE}https://claude.ai/code${NC}"
    echo -e "${DIM}📋 Log file: ${BLUE}$LOG_FILE${NC}"
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
    # Show modern banner
    show_banner
    
    # Status tracking
    echo -e "${DIM}📝 Installation log: $LOG_FILE${NC}"
    echo
    
    # Pre-flight checks
    detect_environments
    check_requirements
    echo
    
    # Interactive setup
    select_environment
    select_project_mode
    echo
    
    # Installation phase
    local env_icon=""
    case "$ENVIRONMENT_TYPE" in
        "local") env_icon="💻" ;;
        "proxmox") env_icon="📦" ;;
        "docker") env_icon="🐳" ;;
    esac
    
    echo -e "${CYAN}${BOLD}🛠️  Installing in $env_icon $ENVIRONMENT_TYPE environment${NC}"
    echo
    
    # Environment-specific installation
    case "$ENVIRONMENT_TYPE" in
        "local")
            setup_local_project
            install_nodejs
            install_claude_code
            echo
            
            # MCP Configuration
            select_mcp_servers
            if [[ -n "$SELECTED_SERVERS" ]]; then
                msg_step "Configuring MCP integrations"
                configure_mcp_servers > /dev/null
                msg_success "MCP servers configured"
            fi
            
            # Create uninstall script
            create_uninstall_script
            ;;
            
        "proxmox")
            create_proxmox_container
            ;;
            
        "docker")
            create_docker_container
            ;;
    esac
    
    # Final status
    echo
    show_instructions
}

# Run main function
main "$@"