#!/usr/bin/env bash

# Proxmox Helper Scripts - Common UI Functions
# Modern, sleek, and intuitive UI components for consistent user experience

# Modern color palette - Material Design inspired
readonly COLOR_PRIMARY='\033[38;5;39m'      # Bright Blue
readonly COLOR_SUCCESS='\033[38;5;46m'      # Bright Green
readonly COLOR_WARNING='\033[38;5;214m'     # Orange
readonly COLOR_ERROR='\033[38;5;196m'       # Bright Red
readonly COLOR_INFO='\033[38;5;45m'         # Cyan
readonly COLOR_MUTED='\033[38;5;245m'       # Gray
readonly COLOR_ACCENT='\033[38;5;213m'      # Pink/Purple
readonly COLOR_HIGHLIGHT='\033[38;5;226m'   # Yellow
readonly COLOR_RESET='\033[0m'

# Text formatting
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly ITALIC='\033[3m'
readonly UNDERLINE='\033[4m'

# Unicode symbols for modern look
readonly SYMBOL_CHECK="✓"
readonly SYMBOL_CROSS="✗"
readonly SYMBOL_INFO="ℹ"
readonly SYMBOL_WARN="⚠"
readonly SYMBOL_ARROW="→"
readonly SYMBOL_BULLET="•"
readonly SYMBOL_STAR="★"
readonly SYMBOL_ROCKET="🚀"
readonly SYMBOL_PACKAGE="📦"
readonly SYMBOL_GEAR="⚙"
readonly SYMBOL_LOCK="🔒"
readonly SYMBOL_KEY="🔑"
readonly SYMBOL_CLOUD="☁"
readonly SYMBOL_SERVER="🖥"

# Progress indicators
readonly SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_PID=""

# Message functions with modern styling
msg() {
    local type="$1"
    local message="$2"
    local symbol="$3"
    local color="$4"
    
    echo -e "${color}${BOLD}${symbol}${COLOR_RESET}  ${message}"
}

msg_info() {
    msg "info" "$1" "${SYMBOL_INFO}" "${COLOR_INFO}"
}

msg_success() {
    msg "success" "$1" "${SYMBOL_CHECK}" "${COLOR_SUCCESS}"
}

msg_error() {
    msg "error" "$1" "${SYMBOL_CROSS}" "${COLOR_ERROR}"
    exit 1
}

msg_warn() {
    msg "warn" "$1" "${SYMBOL_WARN}" "${COLOR_WARNING}"
}

# Section headers with modern styling
section_header() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo ""
    echo -e "${COLOR_PRIMARY}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    printf "${COLOR_PRIMARY}${BOLD}%*s %s %*s${COLOR_RESET}\n" $padding "" "$title" $padding ""
    echo -e "${COLOR_PRIMARY}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
}

# Modern header with gradient-like effect
display_header() {
    local app_name="$1"
    local version="$2"
    local description="$3"
    
    clear
    echo ""
    echo -e "${COLOR_PRIMARY}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║                                                           ║"
    printf "  ║  %-56s ║\n" "$app_name"
    echo "  ║                                                           ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${COLOR_RESET}"
    echo -e "  ${COLOR_MUTED}Version ${version} ${SYMBOL_BULLET} ${description}${COLOR_RESET}"
    echo -e "  ${COLOR_MUTED}Part of Proxmox Helper Scripts Collection${COLOR_RESET}"
    echo ""
}

# Sleek progress bar
progress_bar() {
    local current="$1"
    local total="$2"
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    
    printf "\r  ${COLOR_PRIMARY}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((width - filled))s" | tr ' ' '░'
    printf "] ${BOLD}%3d%%${COLOR_RESET}" $percentage
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Modern spinner
start_spinner() {
    local message="$1"
    
    {
        while true; do
            for frame in "${SPINNER_FRAMES[@]}"; do
                printf "\r  ${COLOR_PRIMARY}${frame}${COLOR_RESET} ${message}"
                sleep 0.1
            done
        done
    } &
    SPINNER_PID=$!
}

stop_spinner() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
        SPINNER_PID=""
        printf "\r%*s\r" 80 ""  # Clear line
    fi
}

# Modern input prompts
prompt_input() {
    local prompt="$1"
    local default="$2"
    local variable_name="$3"
    local input=""
    
    if [[ -n "$default" ]]; then
        echo -e "  ${COLOR_PRIMARY}${SYMBOL_ARROW}${COLOR_RESET} ${prompt} ${COLOR_MUTED}[${default}]${COLOR_RESET}"
        printf "    ${COLOR_PRIMARY}▸${COLOR_RESET} "
        read -r input
        eval "$variable_name=\${input:-\$default}"
    else
        echo -e "  ${COLOR_PRIMARY}${SYMBOL_ARROW}${COLOR_RESET} ${prompt}"
        printf "    ${COLOR_PRIMARY}▸${COLOR_RESET} "
        read -r input
        eval "$variable_name=\$input"
    fi
}

# Modern yes/no prompt
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-yes}"  # Default to yes
    local input=""
    
    if [[ "$default" == "yes" ]]; then
        echo -e "  ${COLOR_PRIMARY}${SYMBOL_ARROW}${COLOR_RESET} ${prompt} ${COLOR_MUTED}[Y/n]${COLOR_RESET}"
    else
        echo -e "  ${COLOR_PRIMARY}${SYMBOL_ARROW}${COLOR_RESET} ${prompt} ${COLOR_MUTED}[y/N]${COLOR_RESET}"
    fi
    
    printf "    ${COLOR_PRIMARY}▸${COLOR_RESET} "
    read -r input
    
    case "${input,,}" in
        y|yes|"")
            [[ "$default" == "yes" ]] && return 0 || [[ -n "$input" ]] && return 0 || return 1
            ;;
        n|no)
            return 1
            ;;
        *)
            msg_warn "Invalid input. Please enter yes or no."
            prompt_yes_no "$prompt" "$default"
            ;;
    esac
}

# Selection menu with modern styling
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    local key=""
    
    # Hide cursor
    tput civis
    
    while true; do
        # Clear menu area
        echo -e "\033[${#options[@]}A\033[J"
        
        echo -e "  ${COLOR_PRIMARY}${SYMBOL_ARROW}${COLOR_RESET} ${prompt}"
        echo ""
        
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "    ${COLOR_PRIMARY}${BOLD}▸ ${options[$i]}${COLOR_RESET}"
            else
                echo -e "    ${COLOR_MUTED}  ${options[$i]}${COLOR_RESET}"
            fi
        done
        
        # Read single character
        read -rsn1 key
        
        case "$key" in
            A)  # Up arrow
                ((selected--))
                [[ $selected -lt 0 ]] && selected=$((${#options[@]} - 1))
                ;;
            B)  # Down arrow
                ((selected++))
                [[ $selected -ge ${#options[@]} ]] && selected=0
                ;;
            "")  # Enter
                break
                ;;
        esac
    done
    
    # Show cursor
    tput cnorm
    
    return $selected
}

# Display configuration summary with modern table
display_config() {
    local -n config=$1
    local title="${2:-Configuration Summary}"
    
    section_header "$title"
    
    echo -e "  ${COLOR_PRIMARY}┌─────────────────────────┬─────────────────────────────────┐${COLOR_RESET}"
    printf "  ${COLOR_PRIMARY}│${COLOR_RESET} %-23s ${COLOR_PRIMARY}│${COLOR_RESET} %-31s ${COLOR_PRIMARY}│${COLOR_RESET}\n" "Setting" "Value"
    echo -e "  ${COLOR_PRIMARY}├─────────────────────────┼─────────────────────────────────┤${COLOR_RESET}"
    
    for key in "${!config[@]}"; do
        printf "  ${COLOR_PRIMARY}│${COLOR_RESET} %-23s ${COLOR_PRIMARY}│${COLOR_RESET} ${COLOR_HIGHLIGHT}%-31s${COLOR_RESET} ${COLOR_PRIMARY}│${COLOR_RESET}\n" "$key" "${config[$key]}"
    done
    
    echo -e "  ${COLOR_PRIMARY}└─────────────────────────┴─────────────────────────────────┘${COLOR_RESET}"
    echo ""
}

# Modern completion banner
display_completion() {
    local app_name="$1"
    shift
    local -n info=$1
    
    echo ""
    echo -e "  ${COLOR_SUCCESS}${BOLD}${SYMBOL_ROCKET} Installation Complete!${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_SUCCESS}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
    
    for section in "${!info[@]}"; do
        echo -e "  ${COLOR_PRIMARY}${BOLD}${section}${COLOR_RESET}"
        echo -e "${info[$section]}" | while IFS= read -r line; do
            echo -e "  ${COLOR_MUTED}${SYMBOL_BULLET}${COLOR_RESET} ${line}"
        done
        echo ""
    done
    
    echo -e "  ${COLOR_ACCENT}${BOLD}Happy coding! ${SYMBOL_STAR}${COLOR_RESET}"
    echo ""
}

# Status indicator with icon
status_indicator() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "running")
            echo -e "  ${COLOR_INFO}${SYMBOL_GEAR} ${message}${COLOR_RESET}"
            ;;
        "success")
            echo -e "  ${COLOR_SUCCESS}${SYMBOL_CHECK} ${message}${COLOR_RESET}"
            ;;
        "error")
            echo -e "  ${COLOR_ERROR}${SYMBOL_CROSS} ${message}${COLOR_RESET}"
            ;;
        "warning")
            echo -e "  ${COLOR_WARNING}${SYMBOL_WARN} ${message}${COLOR_RESET}"
            ;;
    esac
}

# Export all functions
export -f msg msg_info msg_success msg_error msg_warn
export -f section_header display_header progress_bar
export -f start_spinner stop_spinner
export -f prompt_input prompt_yes_no select_option
export -f display_config display_completion status_indicator