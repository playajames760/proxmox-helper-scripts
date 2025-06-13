#!/usr/bin/env bash

# common.sh - Shared utilities for Proxmox Helper Scripts
# Common functions used across multiple installer scripts

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

# Spinner PID storage
SPINNER_PID=""

# Default log file location
LOG_FILE="/tmp/proxmox-helper-$(date +%Y%m%d-%H%M%S).log"

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

# Function to display generic banner
show_banner() {
    local title="$1"
    local subtitle="$2"
    local version="$3"
    
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╭─────────────────────────────────────────────────────╮"
    echo "│                                                     │"
    echo "│  ${WHITE}${title}${CYAN}│"
    echo "│  ${DIM}${WHITE}${subtitle}${CYAN}│"
    echo "│  ${DIM}${WHITE}Version ${version}${CYAN}│"
    echo "│                                                     │"
    echo "╰─────────────────────────────────────────────────────╯"
    echo -e "${NC}"
    echo
}

# Function to detect if running on Proxmox VE
is_proxmox() {
    [[ -f /etc/pve/local/pve-ssl.pem ]] || [[ -f /usr/bin/pvesh ]] || [[ -d /etc/pve ]]
}

# Function to check if Docker is available
has_docker() {
    command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

# Function to check if LXC is available
has_lxc() {
    command -v pct >/dev/null 2>&1
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "This script must be run as root"
        exit 1
    fi
}

# Function to check internet connectivity
check_internet() {
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        msg_error "No internet connection available"
        exit 1
    fi
}

# Function to cleanup on exit
cleanup() {
    stop_spinner
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Function to create temporary directory
create_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    export TEMP_DIR
}

# Function to validate user input
validate_input() {
    local input="$1"
    local pattern="$2"
    local error_msg="$3"
    
    if [[ ! "$input" =~ $pattern ]]; then
        msg_error "$error_msg"
        return 1
    fi
    return 0
}

# Function to prompt for user confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$prompt [Y/n]: " -r reply
            reply=${reply:-y}
        else
            read -p "$prompt [y/N]: " -r reply
            reply=${reply:-n}
        fi
        
        case "$reply" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Function to retry command with exponential backoff
retry_command() {
    local max_attempts="$1"
    local delay="$2"
    local command="$3"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if eval "$command"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            msg_warning "Command failed (attempt $attempt/$max_attempts). Retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi
        
        ((attempt++))
    done
    
    msg_error "Command failed after $max_attempts attempts"
    return 1
}