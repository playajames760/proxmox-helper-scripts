# Proxmox Helper Scripts - UI Standards Guide

## Overview

This guide defines the modern, intuitive UI standards for all Proxmox Helper Scripts. Our goal is to provide a consistent, sleek, and user-friendly experience across all installation scripts.

## Design Principles

### 1. **Modern & Minimal**
- Clean, uncluttered interface
- Strategic use of whitespace
- Clear visual hierarchy
- Professional appearance

### 2. **Intuitive Flow**
- Logical progression through steps
- Clear feedback at every stage
- Smart defaults with easy overrides
- Contextual help when needed

### 3. **Visual Feedback**
- Color-coded messages
- Progress indicators
- Status updates
- Clear success/error states

## Color Palette

Based on Material Design principles with terminal compatibility:

| Purpose | Color Code | Usage |
|---------|------------|-------|
| Primary | `\033[38;5;39m` | Headers, prompts, primary actions |
| Success | `\033[38;5;46m` | Success messages, checkmarks |
| Warning | `\033[38;5;214m` | Warnings, cautions |
| Error | `\033[38;5;196m` | Errors, failures |
| Info | `\033[38;5;45m` | Information, tips |
| Muted | `\033[38;5;245m` | Secondary text, hints |
| Accent | `\033[38;5;213m` | Highlights, special elements |
| Highlight | `\033[38;5;226m` | Values, important data |

## Typography & Icons

### Unicode Symbols
- ✓ Success/Checkmark
- ✗ Error/Cross
- ℹ Information
- ⚠ Warning
- → Arrow/Direction
- • Bullet point
- ▸ Selection indicator
- 🚀 Launch/Complete
- 📦 Package/Install
- ⚙ Settings/Processing
- 🔒 Security/Lock
- 🖥 Server/System

### Text Formatting
- **Bold** (`\033[1m`) - Headers, important text
- *Dim* (`\033[2m`) - Less important information
- *Italic* (`\033[3m`) - Emphasis (if supported)
- Underline (`\033[4m`) - Links, special text

## UI Components

### 1. Headers

```bash
display_header "Service Name" "1.0.0" "Brief description"
```

Output:
```
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║  Service Name                                             ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
  
  Version 1.0.0 • Brief description
  Part of Proxmox Helper Scripts Collection
```

### 2. Section Headers

```bash
section_header "Configuration"
```

Output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 3. Messages

```bash
msg_info "Checking requirements..."
msg_success "Installation complete"
msg_warn "Using default settings"
msg_error "Failed to connect"
```

Output:
```
ℹ  Checking requirements...
✓  Installation complete
⚠  Using default settings
✗  Failed to connect
```

### 4. Input Prompts

```bash
prompt_input "Container name" "my-service" "CONFIG[name]"
```

Output:
```
  → Container name [my-service]
    ▸ _
```

### 5. Yes/No Prompts

```bash
prompt_yes_no "Enable monitoring?" "yes"
```

Output:
```
  → Enable monitoring? [Y/n]
    ▸ _
```

### 6. Progress Indicators

#### Progress Bar
```bash
progress_bar 7 10
```

Output:
```
  [████████████████████████████░░░░░░░░░░░░]  70%
```

#### Spinner
```bash
start_spinner "Installing packages..."
# ... do work ...
stop_spinner
```

Output:
```
  ⠙ Installing packages...
```

### 7. Configuration Summary

```bash
declare -A config=(
    ["Container ID"]="101"
    ["CPU Cores"]="4"
    ["RAM"]="8192 MB"
)
display_config config
```

Output:
```
  ┌─────────────────────────┬─────────────────────────────────┐
  │ Setting                 │ Value                           │
  ├─────────────────────────┼─────────────────────────────────┤
  │ Container ID            │ 101                             │
  │ CPU Cores               │ 4                               │
  │ RAM                     │ 8192 MB                         │
  └─────────────────────────┴─────────────────────────────────┘
```

### 8. Completion Banner

```bash
declare -A info=(
    ["Container Details"]="ID: 101\nIP: 192.168.1.100"
    ["Access"]="SSH: ssh root@192.168.1.100"
)
display_completion "My Service" info
```

Output:
```
  🚀 Installation Complete!
  
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Container Details
  • ID: 101
  • IP: 192.168.1.100
  
  Access
  • SSH: ssh root@192.168.1.100
  
  Happy coding! ★
```

## Implementation Guidelines

### 1. Script Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

# Load UI functions
source <(curl -fsSL .../templates/common-ui.sh)

# Display header
display_header "Service Name" "1.0.0" "Description"

# Check requirements
section_header "System Check"
msg_info "Checking requirements..."

# Configuration
section_header "Configuration"
prompt_input "Setting" "default" "variable"

# Installation
section_header "Installation"
progress_bar 0 100

# Completion
display_completion "Service" completion_info
```

### 2. Error Handling

- Always provide clear error messages
- Include recovery suggestions when possible
- Clean up on failure
- Use exit codes appropriately

### 3. User Input

- Provide sensible defaults
- Validate all input
- Show clear error messages for invalid input
- Allow users to retry on errors

### 4. Progress Feedback

- Use spinners for indeterminate operations
- Use progress bars for known steps
- Update status messages regularly
- Clear spinners/progress when done

## Best Practices

### DO:
- ✓ Keep messages concise and clear
- ✓ Use consistent spacing and alignment
- ✓ Provide visual feedback for all operations
- ✓ Test on different terminal sizes
- ✓ Handle Ctrl+C gracefully
- ✓ Clear the screen appropriately
- ✓ Use color to enhance, not distract

### DON'T:
- ✗ Overuse colors or animations
- ✗ Create walls of text
- ✗ Hide errors or warnings
- ✗ Use hard-coded values
- ✗ Assume terminal capabilities
- ✗ Mix UI styles

## Testing

Before releasing, test your script:

1. **Different terminals**: bash, zsh, ssh sessions
2. **Different sizes**: 80x24, 120x40, etc.
3. **Color support**: 8-color, 256-color, no color
4. **Input scenarios**: defaults, invalid input, edge cases
5. **Error conditions**: network failures, permission issues
6. **Interruptions**: Ctrl+C at various stages

## Examples

See the `templates/install-template.sh` for a complete implementation example that follows all these standards.