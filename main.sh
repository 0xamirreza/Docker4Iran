#!/bin/bash

# =============================================================================
# DOCKER INSTALLER WITH DNS OPTIMIZATION
# =============================================================================
# Combines DNS selection, Docker installation, and management tools
# =============================================================================


set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
function log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

function log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function show_header() {
    clear
    echo "============================================================"
    echo " dP\"Yb  Yb  dP 8888b.   dP\"Yb   dP\"\"b8 88  dP 888888 88\"\"Yb"
    echo "dP   Yb  YbdP   8I  Yb dP   Yb dP   \`\" 88odP  88__   88__dP"
    echo "Yb   dP  dPYb   8I  dY Yb   dP Yb      88\"Yb  88\"\"   88\"Yb"
    echo " YbodP  dP  Yb 8888Y\"   YbodP   YboodP 88  Yb 888888 88  Yb"
    echo "============================================================"
    echo "           DOCKER INSTALLER WITH DNS OPTIMIZATION"
    echo "============================================================"
    echo "                  Author: 0xAmirreza"
    echo "                     License: MIT"
    echo "============================================================"
    if [ -f "VERSION" ]; then
        VERSION=$(cat VERSION)
        echo "                    Version: $VERSION"
    fi
    echo "------------------------------------------------------------"
    echo ""
}

function check_requirements() {
    log_info "Checking system requirements..."
    
    # Check if running as root or with sudo access
    if [ "$(id -u)" -eq 0 ]; then
        log_warning "Running as root user"
    elif ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo privileges"
        echo "Please run with sudo or ensure your user has sudo access"
        exit 1
    fi
    
    # Check Python3 availability
    if ! command -v python3 &> /dev/null; then
        log_warning "Python3 not found. Installing..."
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip
    fi
    
    # Check if DNS selector script exists
    if [ ! -f "$SCRIPT_DIR/dns_selector.py" ]; then
        log_error "DNS selector script not found: $SCRIPT_DIR/dns_selector.py"
        exit 1
    fi
    
    log_success "System requirements check completed"
}

function optimize_dns() {
    log_info "Starting DNS optimization process..."
    
    cd "$SCRIPT_DIR"
    
    # Make DNS selector executable
    chmod +x dns_selector.py
    
    # Run DNS optimization with Docker connectivity focus
    echo ""
    log_info "Testing DNS servers for Docker connectivity..."
    echo "This will test each DNS server's ability to connect to Docker download servers."
    echo ""
    
    if python3 dns_selector.py; then
        log_success "DNS optimization completed successfully"
        
        # Test Docker connectivity with selected DNS
        log_info "Testing Docker connectivity with selected DNS..."
        if curl -I --connect-timeout 10 https://download.docker.com >/dev/null 2>&1; then
            log_success "Docker connectivity test passed!"
            return 0
        else
            log_warning "Docker connectivity test failed, but continuing..."
            return 0
        fi
    else
        log_warning "DNS optimization failed or was skipped"
        log_info "Continuing with system default DNS..."
        
        # Test with current DNS
        log_info "Testing Docker connectivity with current DNS..."
        if curl -I --connect-timeout 10 https://download.docker.com >/dev/null 2>&1; then
            log_success "Docker connectivity test passed with current DNS!"
            return 0
        else
            log_error "Docker connectivity test failed!"
            echo "This may cause Docker installation to fail."
            echo "Consider running DNS optimization again or checking your internet connection."
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                return 0
            else
                return 1
            fi
        fi
    fi
}

function optimize_docker_registry() {
    log_info "Starting Docker registry mirror optimization..."
    
    cd "$SCRIPT_DIR"
    
    # Check if registry selector script exists
    if [ ! -f "$SCRIPT_DIR/mirror_selector.py" ]; then
        log_error "Registry selector script not found: $SCRIPT_DIR/mirror_selector.py"
        return 1
    fi
    
    # Make registry selector executable
    chmod +x mirror_selector.py
    
    # Check if we have Python3 and required modules
    if ! command -v python3 &> /dev/null; then
        log_warning "Python3 not found. Installing..."
        apt-get update
        apt-get install -y python3 python3-pip
    fi
    
    # Install required Python modules
    log_info "Installing required Python modules..."
    pip3 install requests >/dev/null 2>&1 || {
        log_warning "pip3 install failed, trying with apt..."
        apt-get install -y python3-requests
    }
    
    # Run registry mirror optimization
    echo ""
    log_info "Testing Docker registry mirrors for optimal performance..."
    echo "This will test all available mirrors and let you choose the best one..."
    echo ""
    
    # Run the registry selector
    if python3 mirror_selector.py; then
        log_success "Docker registry mirror optimization completed!"
    else
        log_warning "Registry mirror optimization failed or was skipped"
        log_info "You can run it manually later with: sudo python3 mirror_selector.py"
    fi
    
    echo ""
    log_info "Registry optimization process finished"
}

function run_docker_mirror_registry() {
    log_info "Starting Docker Mirror Registry Selector..."
    
    cd "$SCRIPT_DIR"
    
    # Check if registry selector script exists
    if [ ! -f "$SCRIPT_DIR/mirror_selector.py" ]; then
        log_error "Mirror selector script not found: $SCRIPT_DIR/mirror_selector.py"
        log_info "Please ensure mirror_selector.py is in the same directory as this script"
        return 1
    fi
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        log_info "Please install Docker first using option 3 or 1"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running!"
        log_info "Please start Docker service: sudo systemctl start docker"
        return 1
    fi
    
    # Check if we have Python3 and required modules
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 is required but not installed"
        log_info "Please install Python3: sudo apt install python3 python3-pip"
        return 1
    fi
    
    # Install required Python modules if needed
    if ! python3 -c "import requests" >/dev/null 2>&1; then
        log_info "Installing required Python modules..."
        pip3 install requests >/dev/null 2>&1 || {
            log_warning "pip3 install failed, trying with apt..."
            sudo apt-get update
            sudo apt-get install -y python3-requests
        }
    fi
    
    # Make registry selector executable
    chmod +x mirror_selector.py
    
    # Run the registry selector with sudo
    echo ""
    log_info "Launching Docker Mirror Registry Selector..."
    echo "This will test all available Docker registry mirrors and let you choose the best one."
    echo ""
    
    if sudo python3 mirror_selector.py; then
        log_success "Docker Mirror Registry configuration completed!"
    else
        log_warning "Docker Mirror Registry configuration failed or was cancelled"
    fi
    
    echo ""
}

function install_docker() {
    log_info "Starting Docker installation..."
    
    # Ensure we have sudo privileges throughout the script
    if [ "$(id -u)" -ne 0 ]; then
        log_info "Re-launching Docker installation with sudo..."
        exec sudo "$0" install_docker_as_root
        exit $?
    fi
    
    install_docker_as_root
}

function install_docker_as_root() {
    # Improved distribution detection
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_NAME="$NAME"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO_ID="$(echo "$DISTRIB_ID" | tr '[:upper:]' '[:lower:]')"
        DISTRO_NAME="$DISTRIB_DESCRIPTION"
    elif [ -f /etc/debian_version ]; then
        DISTRO_ID="debian"
        DISTRO_NAME="Debian"
    else
        log_error "Unable to detect distribution."
        exit 1
    fi

    # Set DISTRO based on ID
    if [[ "$DISTRO_ID" == "ubuntu" ]]; then
        DISTRO="ubuntu"
    elif [[ "$DISTRO_ID" == "debian" ]]; then
        DISTRO="debian"
    else
        log_error "Unsupported distribution: $DISTRO_ID ($DISTRO_NAME)"
        echo "This script only supports Ubuntu and Debian."
        exit 1
    fi

    log_info "Detected distribution: $DISTRO ($DISTRO_NAME)"

    # Install lsb-release if not available
    if ! command -v lsb_release &>/dev/null; then
        log_info "Installing lsb-release..."
        apt-get update 2>/dev/null || log_warning "Could not update package lists with current repos"
        apt-get install -y lsb-release 2>/dev/null || {
            log_warning "Could not install lsb-release with current repos. Will continue without it."
            DISTRO_CODENAME="unknown"
            DISTRO_VERSION="unknown"
        }
    fi

    # Get distribution details if lsb_release is available
    if command -v lsb_release &>/dev/null; then
        DISTRO_CODENAME=$(lsb_release -cs)
        DISTRO_VERSION=$(lsb_release -rs)
    else
        # Fallback: try to get codename from os-release
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO_CODENAME="${VERSION_CODENAME:-unknown}"
            DISTRO_VERSION="${VERSION_ID:-unknown}"
        fi
    fi

    log_info "Detected $DISTRO $DISTRO_VERSION ($DISTRO_CODENAME)"

    # Validate codename for the distribution
    if [ "$DISTRO" = "ubuntu" ]; then
        VALID_CODENAMES="bionic focal jammy lunar mantic noble oracular plucky"
        if [[ ! " $VALID_CODENAMES " =~ " $DISTRO_CODENAME " ]]; then
            log_warning "Unrecognized Ubuntu codename '$DISTRO_CODENAME'"
            log_info "Using 'noble' (24.04 LTS) as fallback"
            DISTRO_CODENAME="noble"
        fi
    elif [ "$DISTRO" = "debian" ]; then
        VALID_CODENAMES="stretch buster bullseye bookworm trixie sid"
        if [[ ! " $VALID_CODENAMES " =~ " $DISTRO_CODENAME " ]]; then
            log_warning "Unrecognized Debian codename '$DISTRO_CODENAME'"
            log_info "Using 'bookworm' (12) as fallback"
            DISTRO_CODENAME="bookworm"
        fi
    fi

    # Completely clean up all repository configurations
    log_info "Cleaning up repository configurations..."
    mkdir -p /etc/apt/sources.list.d.backup
    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.original.backup
    fi

    # Move all existing source files to backup
    mv /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d.backup/ 2>/dev/null || true
    mv /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d.backup/ 2>/dev/null || true

    # Create a clean sources.list based on distribution
    log_info "Setting up standard $DISTRO repositories for codename: $DISTRO_CODENAME"

    if [ "$DISTRO" = "ubuntu" ]; then
        cat > /etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu/ $DISTRO_CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $DISTRO_CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $DISTRO_CODENAME-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $DISTRO_CODENAME-security main restricted universe multiverse
EOF
    elif [ "$DISTRO" = "debian" ]; then
        cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian $DISTRO_CODENAME main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $DISTRO_CODENAME-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $DISTRO_CODENAME-security main contrib non-free non-free-firmware
EOF
    fi

    # Update and install prerequisites
    log_info "Updating package lists and installing prerequisites..."
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release

    # Add Docker's official GPG key
    log_info "Adding Docker's GPG key..."
    if [ "$DISTRO" = "ubuntu" ]; then
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    elif [ "$DISTRO" = "debian" ]; then
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    fi
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    log_info "Setting up Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO $DISTRO_CODENAME stable" > /etc/apt/sources.list.d/docker.list

    # Update package lists with Docker repository
    log_info "Updating package lists..."
    apt-get update

    # Install Docker
    log_info "Installing Docker packages..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker service
    log_info "Starting Docker service..."
    systemctl start docker
    systemctl enable docker

    # Add current user to docker group (if not root)
    if [ "$SUDO_USER" ]; then
        log_info "Adding user $SUDO_USER to docker group..."
        usermod -aG docker "$SUDO_USER"
        log_warning "Please log out and back in for group changes to take effect"
    fi

    # Verify installation
    log_info "Verifying Docker installation..."
    if docker --version && docker compose version; then
        log_success "Docker installation completed successfully!"
        docker --version
        docker compose version
        
        # Run registry mirror selector after successful installation
        optimize_docker_registry
    else
        log_error "Docker installation verification failed"
        exit 1
    fi
}

function launch_management_tool() {
    log_info "Installing and launching Docker management tool..."
    
    if [ -f "$SCRIPT_DIR/0xDocker.sh" ]; then
        # First run the script to trigger self-installation
        log_info "Installing 0xdocker command..."
        bash "$SCRIPT_DIR/0xDocker.sh"
        
        # Verify installation
        if [ -f "$HOME/.local/bin/0xdocker" ]; then
            log_success "0xdocker installed successfully to ~/.local/bin/0xdocker"
            
            # Add ~/.local/bin to current PATH if not already there
            if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
                export PATH="$HOME/.local/bin:$PATH"
                log_info "Added ~/.local/bin to current session PATH"
            fi
            
            # Update command hash to ensure the new command is found
            hash -r 2>/dev/null || true
            
            # Test if command is now available
            if command -v 0xdocker >/dev/null 2>&1; then
                log_success "0xdocker command is now available!"
                log_info "Launching 0xdocker management tool..."
                
                # Launch using the installed command
                "$HOME/.local/bin/0xdocker"
            else
                log_warning "0xdocker command not found in PATH"
                log_info "Launching management tool directly..."
                bash "$SCRIPT_DIR/0xDocker.sh"
                echo ""
                log_info "To use '0xdocker' command in future, restart your terminal or run:"
                echo "  source ~/.bashrc"
            fi
        else
            log_error "Installation failed - 0xdocker executable not found"
            log_info "Launching management tool directly..."
            bash "$SCRIPT_DIR/0xDocker.sh"
        fi
    else
        log_error "Docker management tool not found: $SCRIPT_DIR/0xDocker.sh"
    fi
}

function uninstall_docker() {
    log_info "Uninstalling Docker..."
    
    if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$0" uninstall_docker_as_root
        exit $?
    fi
    
    uninstall_docker_as_root
}

function uninstall_docker_as_root() {
    log_warning "This will completely remove Docker and all containers, images, and volumes"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Stopping Docker services..."
        systemctl stop docker containerd || true
        
        log_info "Removing Docker packages..."
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras || true
        
        log_info "Removing Docker data..."
        rm -rf /var/lib/docker
        rm -rf /var/lib/containerd
        
        log_info "Removing Docker repository..."
        rm -f /etc/apt/sources.list.d/docker.list
        rm -f /etc/apt/keyrings/docker.gpg
        
        log_success "Docker uninstalled successfully"
    else
        log_info "Uninstallation cancelled"
    fi
}

function uninstall_0xdocker() {
    log_info "Uninstalling 0xDocker management tool..."
    
    # Get the actual user (not root when using sudo)
    local ACTUAL_USER="${SUDO_USER:-$USER}"
    local USER_HOME=$(eval echo ~$ACTUAL_USER)
    local INSTALL_PATH="$USER_HOME/.local/bin"
    local TARGET="$INSTALL_PATH/0xdocker"
    local LOG_FILE="$USER_HOME/.local/share/0xdocker.log"
    local REMOVED_ITEMS=()
    
    # Remove the executable
    if [ -f "$TARGET" ]; then
        rm -f "$TARGET"
        REMOVED_ITEMS+=("Executable: $TARGET")
        log_success "Removed 0xdocker executable"
    else
        log_warning "0xdocker executable not found at $TARGET"
    fi
    
    # Remove log file
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
        REMOVED_ITEMS+=("Log file: $LOG_FILE")
        log_success "Removed 0xdocker log file"
    fi
    
    # Remove log directory if empty
    local LOG_DIR="$(dirname "$LOG_FILE")"
    if [ -d "$LOG_DIR" ] && [ -z "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
        rmdir "$LOG_DIR" 2>/dev/null || true
        REMOVED_ITEMS+=("Empty log directory: $LOG_DIR")
    fi
    
    # Check for PATH modifications (informational only)
    local SHELL_RC="$USER_HOME/.bashrc"
    [[ "$SHELL" =~ zsh ]] && SHELL_RC="$USER_HOME/.zshrc"
    
    if [ -f "$SHELL_RC" ] && grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_RC"; then
        log_warning "Found PATH modification in $SHELL_RC"
        echo "Note: The PATH modification in $SHELL_RC was not removed automatically"
        echo "You may want to manually remove this line if you no longer need it:"
        echo '  export PATH="$HOME/.local/bin:$PATH"'
    fi
    
    # Clear command hash to prevent cached execution
    hash -d 0xdocker 2>/dev/null || true
    
    if [ ${#REMOVED_ITEMS[@]} -gt 0 ]; then
        log_success "0xDocker uninstalled successfully!"
        echo "Removed items:"
        for item in "${REMOVED_ITEMS[@]}"; do
            echo "  - $item"
        done
        echo ""
        log_info "Command hash cleared. 0xdocker command should no longer work."
    else
        log_warning "0xDocker was not found or already uninstalled"
        # Still clear the hash in case it was cached
        log_info "Command hash cleared just in case."
    fi
}

function uninstall_0xdocker_complete() {
    log_info "Completely uninstalling 0xDocker (Management Tool + Service)..."
    
    # First uninstall the service if it exists
    local SERVICE_FILE="/etc/systemd/system/0xdocker.service"
    if [ -f "$SERVICE_FILE" ]; then
        log_info "Found 0xDocker service. Uninstalling service first..."
        uninstall_0xdocker_service
        echo ""
    fi
    
    # Then uninstall the management tool
    log_info "Uninstalling 0xDocker management tool..."
    uninstall_0xdocker
    
    log_success "Complete 0xDocker uninstallation finished!"
}

function install_0xdocker_service() {
    log_info "Installing 0xDocker as a system service..."
    
    # Get the actual user (not root when using sudo)
    local ACTUAL_USER="${SUDO_USER:-$USER}"
    local USER_HOME=$(eval echo ~$ACTUAL_USER)
    local EXECUTABLE="$USER_HOME/.local/bin/0xdocker"
    
    # First ensure 0xdocker is installed
    if [ ! -f "$EXECUTABLE" ]; then
        log_info "0xdocker not found at $EXECUTABLE. Installing first..."
        
        # Run installation as the actual user, not root
        if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ]; then
            # We're running as root via sudo, run installation as the original user
            sudo -u "$SUDO_USER" bash "$SCRIPT_DIR/0xDocker.sh"
        else
            # We're running as regular user
            bash "$SCRIPT_DIR/0xDocker.sh"
        fi
        
        if [ ! -f "$EXECUTABLE" ]; then
            log_error "Failed to install 0xdocker at $EXECUTABLE. Cannot create service."
            return 1
        fi
        log_success "0xdocker installed successfully at $EXECUTABLE"
    fi
    
    # Check if running as root (required for systemd service installation)
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Root privileges required to install system service"
        exec sudo "$0" install_0xdocker_service_as_root
        exit $?
    fi
    
    install_0xdocker_service_as_root
}

function install_0xdocker_service_as_root() {
    local SERVICE_NAME="0xdocker"
    local SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    local USER_HOME=$(eval echo ~$SUDO_USER)
    local EXECUTABLE="$USER_HOME/.local/bin/0xdocker"
    
    # Verify the executable exists
    if [ ! -f "$EXECUTABLE" ]; then
        log_error "0xdocker executable not found at $EXECUTABLE"
        return 1
    fi
    
    log_info "Creating systemd service file..."
    
    # Create the service file
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=0xDocker Management Service
Documentation=https://github.com/0xAmirreza/Docker-setup
After=docker.service
Wants=docker.service

[Service]
Type=simple
User=$SUDO_USER
Group=$SUDO_USER
ExecStart=$EXECUTABLE --daemon
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=0xdocker

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=false
ReadWritePaths=$USER_HOME/.local/share

[Install]
WantedBy=multi-user.target
EOF

    if [ $? -eq 0 ]; then
        log_success "Service file created: $SERVICE_FILE"
        
        # Reload systemd and enable the service
        log_info "Reloading systemd daemon..."
        systemctl daemon-reload
        
        log_info "Enabling 0xdocker service..."
        systemctl enable "$SERVICE_NAME"
        
        log_info "Starting 0xdocker service..."
        systemctl start "$SERVICE_NAME"
        
        # Check service status
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log_success "0xdocker service installed and started successfully!"
            echo ""
            echo "Service management commands:"
            echo "  • Check status: sudo systemctl status $SERVICE_NAME"
            echo "  • Stop service: sudo systemctl stop $SERVICE_NAME"
            echo "  • Start service: sudo systemctl start $SERVICE_NAME"
            echo "  • Restart service: sudo systemctl restart $SERVICE_NAME"
            echo "  • View logs: sudo journalctl -u $SERVICE_NAME -f"
            echo "  • Disable service: sudo systemctl disable $SERVICE_NAME"
        else
            log_error "Service created but failed to start. Check logs with:"
            echo "  sudo journalctl -u $SERVICE_NAME -n 20"
        fi
    else
        log_error "Failed to create service file"
        return 1
    fi
}

function uninstall_0xdocker_service() {
    log_info "Uninstalling 0xDocker system service..."
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Root privileges required to uninstall system service"
        exec sudo "$0" uninstall_0xdocker_service_as_root
        exit $?
    fi
    
    uninstall_0xdocker_service_as_root
}

function uninstall_0xdocker_service_as_root() {
    local SERVICE_NAME="0xdocker"
    local SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    if [ -f "$SERVICE_FILE" ]; then
        log_info "Stopping 0xdocker service..."
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        
        log_info "Disabling 0xdocker service..."
        systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        
        log_info "Removing service file..."
        rm -f "$SERVICE_FILE"
        
        log_info "Reloading systemd daemon..."
        systemctl daemon-reload
        
        log_success "0xdocker service uninstalled successfully!"
    else
        log_warning "0xdocker service not found or already uninstalled"
    fi
}

function show_menu() {
    while true; do
        show_header
        echo "Please select an option:"
        echo ""
        echo "1.Full Installation (DNS Optimization + Docker + Management Tool + Mirror Registry)"
        echo "2.DNS Optimization"
        echo "3.Docker Installation Only"
        echo "4.0xDocker"
        echo "5.Mirror Registry"
        echo "6.Install 0xDocker as System Service"
        echo "7.Uninstall Docker"
        echo "8.Completely Uninstall 0xDocker (Tool + Service)"
        echo "9.Exit"
        echo ""
        read -p "Enter your choice (1-9): " choice

        case $choice in
            1)
                log_info "Starting full installation..."
                check_requirements
                optimize_dns
                install_docker
                install_0xdocker_service
                optimize_docker_registry
                log_success "Full installation completed!"
                echo ""
                log_info "Your system now has:"
                echo "  ✅ Optimized DNS settings"
                echo "  ✅ Docker installed and running"
                echo "  ✅ 0xDocker management service installed and running"
                echo "  ✅ Docker registry mirror optimized"
                echo ""
                log_info "You can manage the 0xDocker service with:"
                echo "  • Check status: sudo systemctl status 0xdocker"
                echo "  • View logs: sudo journalctl -u 0xdocker -f"
                echo "  • Run interactively: 0xdocker"
                echo ""
                log_info "You can reconfigure Docker registry mirrors anytime with:"
                echo "  • Run: sudo python3 mirror_selector.py"
                echo "  • Or use menu option 5"
                read -p "Press Enter to continue..."
                ;;
            2)
                log_info "Starting DNS optimization..."
                check_requirements
                optimize_dns
                read -p "Press Enter to continue..."
                ;;
            3)
                log_info "Starting Docker installation..."
                check_requirements
                install_docker
                read -p "Press Enter to continue..."
                ;;
            4)
                launch_management_tool
                read -p "Press Enter to continue..."
                ;;
            5)
                run_docker_mirror_registry
                read -p "Press Enter to continue..."
                ;;
            6)
                install_0xdocker_service
                read -p "Press Enter to continue..."
                ;;
            7)
                uninstall_docker
                read -p "Press Enter to continue..."
                ;;
            8)
                uninstall_0xdocker_complete
                read -p "Press Enter to continue..."
                ;;
            9)
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Handle direct function calls (for sudo re-execution)
if [ "$1" = "install_docker_as_root" ]; then
    install_docker_as_root
    exit $?
elif [ "$1" = "uninstall_docker_as_root" ]; then
    uninstall_docker_as_root
    exit $?
elif [ "$1" = "install_0xdocker_service_as_root" ]; then
    install_0xdocker_service_as_root
    exit $?
elif [ "$1" = "uninstall_0xdocker_service_as_root" ]; then
    uninstall_0xdocker_service_as_root
    exit $?
fi

# Main menu
show_menu
