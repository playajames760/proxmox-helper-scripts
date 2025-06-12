# Personal Proxmox Helper Scripts

A comprehensive collection of automation scripts for Proxmox VE, designed to simplify container deployment, VM management, and infrastructure automation. Built for personal use with full customization control.

## 🚀 Available Scripts

### 🤖 Claude Code Development Environment
Complete AI-powered development environment with Claude Code integration.

**Quick Install:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/scripts/claude-code-dev/install.sh)
```

**Features:**
- Claude Code with authentication setup
- Node.js 20 LTS development stack  
- VS Code Server (web-based IDE)
- Git workflow with GPG signing
- Docker and containerization tools
- Project templates and custom commands
- Security hardening and monitoring

**Resources:** 4 vCPU, 8GB RAM, 20GB storage (customizable)

[📖 Detailed Documentation](scripts/claude-code-dev/README.md)

---

### 🔮 Coming Soon

#### 🐳 Docker Host Environment
Complete containerization platform for development and production workloads.
- Docker CE with Docker Compose
- Portainer web management interface
- Container registry integration
- Automated backup solutions

#### 🏠 Home Assistant Platform
Comprehensive home automation hub with add-on ecosystem.
- Home Assistant OS in LXC
- MQTT broker integration
- Z-Wave and Zigbee support
- Mobile app connectivity

#### 📺 Media Server Stack
Complete entertainment server with streaming capabilities.
- Plex or Jellyfin media server
- Sonarr/Radarr automation
- VPN integration for security
- Storage optimization

#### 🌐 Web Server Platform
Production-ready web hosting environment.
- Nginx or Apache with SSL automation
- PHP/Python/Node.js support
- Database integration (MySQL/PostgreSQL)
- Automated backup and monitoring

#### 📊 Monitoring Stack
Comprehensive infrastructure monitoring solution.
- Prometheus metrics collection
- Grafana visualization dashboards
- Alertmanager notifications
- Log aggregation with Loki

#### 🗄️ Database Clusters
High-availability database solutions.
- PostgreSQL/MySQL clusters
- Redis caching layers
- Automated backup systems
- Performance monitoring

## 🎯 Design Philosophy

### ✅ Core Principles
- **One-Command Installation** - Deploy complex environments instantly
- **Interactive Configuration** - User-friendly setup dialogs
- **Security First** - Hardened containers with best practices
- **Modular Design** - Reusable components across scripts
- **Comprehensive Documentation** - Clear guides for everything
- **Easy Customization** - Fork-friendly architecture

### 🛡️ Security Standards
- **Unprivileged Containers** - Enhanced security by default
- **Firewall Integration** - UFW with sensible defaults
- **SSH Key Authentication** - Password authentication disabled
- **Automatic Updates** - Security patches and dependency management
- **AppArmor Profiles** - Additional security layers
- **Regular Auditing** - Built-in security checks

### 📋 Script Standards
All scripts follow consistent patterns:
- Modern, intuitive UI with sleek visual design
- Interactive configuration with smart defaults
- Real-time progress indicators and status updates
- Comprehensive error handling and validation
- Automatic service configuration and health checks
- Built-in update mechanisms and maintenance tools
- Detailed logging and troubleshooting support

## 📦 System Requirements

### Proxmox VE Host
- **Version**: Proxmox VE 8.0+ (7.x may work but not tested)
- **Resources**: Varies by script (see individual documentation)
- **Storage**: Local or shared storage with adequate space
- **Network**: Internet connectivity for downloads and updates
- **Access**: Root access to Proxmox VE host

### General Container Requirements
- **CPU**: 2-8 cores depending on service
- **RAM**: 2-16GB depending on workload
- **Storage**: 10-100GB depending on data requirements
- **Network**: Bridge or VLAN access as needed

## 🚀 Quick Start Guide

### 1. Choose Your Script
Browse available scripts and select based on your needs:
- **Development**: Claude Code environment
- **Infrastructure**: Docker host, monitoring
- **Applications**: Home Assistant, media server
- **Services**: Web server, databases

### 2. Deploy with One Command
```bash
# Replace with your chosen script path
bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/scripts/SERVICE-NAME/install.sh)
```

### 3. Follow Interactive Setup
- Answer configuration prompts
- Customize resources and features
- Wait for automatic installation
- Access your new environment

### 4. Post-Installation
- SSH into container or access web interface
- Complete service-specific setup
- Configure security and monitoring
- Start using your new environment

## 🔧 Installation Methods

### Interactive Installation (Default)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/scripts/claude-code-dev/install.sh)
```
- Guided setup with configuration prompts
- Resource allocation customization
- Feature selection (optional components)
- Network and security configuration

### Automatic Installation
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/scripts/claude-code-dev/install.sh) --auto
```
- Uses sensible defaults for quick deployment
- Minimal interaction required
- Ideal for testing or standardized deployments
- Can be combined with environment variables for customization

### Advanced Configuration
```bash
# Use environment variables for customization
CT_CORES=8 CT_RAM=16384 bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/main/scripts/claude-code-dev/install.sh) --auto
```

### Branch-Based Testing
```bash
# Test development features
bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/dev/scripts/claude-code-dev/install.sh)

# Use specific version tags
bash <(curl -fsSL https://raw.githubusercontent.com/playajames760/proxmox-helper-scripts/v1.0.0/scripts/claude-code-dev/install.sh)
```

## 🛠️ Repository Structure

```
proxmox-helper-scripts/
├── README.md                    # This file
├── scripts/                     # Individual script collections
│   ├── claude-code-dev/        # Claude Code development environment
│   │   ├── install.sh          # Main installer
│   │   ├── setup.sh           # Container configuration
│   │   ├── templates/         # Project templates
│   │   └── README.md          # Detailed documentation
│   ├── docker-host/           # Docker platform (coming soon)
│   ├── home-assistant/        # Home automation (coming soon)
│   ├── media-server/          # Entertainment platform (coming soon)
│   ├── web-server/            # Web hosting platform (coming soon)
│   └── monitoring/            # Infrastructure monitoring (coming soon)
├── templates/                  # Shared resources and UI components
│   ├── common-ui.sh          # Modern UI functions library
│   ├── install-template.sh   # Standard installation script template
│   ├── ui-demo.sh           # Interactive UI components demo
│   ├── lxc-base.conf        # Base LXC configurations
│   └── security-hardening.sh # Security configuration templates
├── tools/                     # Management utilities
│   ├── backup-automation.sh  # Automated backup solutions
│   ├── bulk-operations.sh    # Mass container management
│   ├── health-monitoring.sh  # System health checks
│   └── update-manager.sh     # Update management across containers
├── docs/                      # Documentation
│   ├── ui-standards.md       # Modern UI design guidelines
│   ├── installation-guide.md # General installation instructions
│   ├── customization.md      # Modification and customization guide
│   ├── troubleshooting.md    # Common issues and solutions
│   ├── security-guide.md     # Security best practices
│   └── api-reference.md      # Script API and integration guide
└── examples/                  # Usage examples and configurations
    ├── production-configs/    # Production-ready configurations
    ├── development-setups/    # Development environment examples
    └── integration-examples/  # Service integration patterns
```

---

**🚀 Transform your Proxmox infrastructure with powerful automation scripts!**

*Start with the Claude Code development environment and scale to manage your entire infrastructure with confidence.*