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

function extract_embedded_script() {
    local section_name="$1"
    local output_file="$2"

    awk "/^__${section_name}_BEGIN__$/ {found=1; next} /^__${section_name}_END__$/ {found=0} found" "$0" > "$output_file"
    chmod +x "$output_file"
}

function run_embedded_selector() {
    local selector_mode="$1"
    local selector_script

    selector_script="$(mktemp /tmp/docker4iran-selector.XXXXXX.sh)"
    extract_embedded_script "SELECTORS_SH" "$selector_script"
    DOCKER4IRAN_SCRIPT_DIR="$SCRIPT_DIR" bash "$selector_script" "$selector_mode"
    local exit_code=$?
    rm -f "$selector_script"
    return "$exit_code"
}

function run_embedded_0xdocker() {
    local management_script

    management_script="$(mktemp /tmp/docker4iran-0xdocker.XXXXXX.sh)"
    extract_embedded_script "ZEROXDOCKER_SH" "$management_script"
    DOCKER4IRAN_EMBEDDED=1 bash "$management_script" "$@"
    local exit_code=$?
    rm -f "$management_script"
    return "$exit_code"
}

function install_0xdocker_executable() {
    local actual_user="${SUDO_USER:-$USER}"
    local user_home
    local install_path
    local target
    local shell_rc

    user_home="$(eval echo "~$actual_user")"
    install_path="$user_home/.local/bin"
    target="$install_path/0xdocker"

    if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" mkdir -p "$install_path"
        cp "$0" "$target"
        chown "$SUDO_USER:$SUDO_USER" "$target"
    else
        mkdir -p "$install_path"
        cp "$0" "$target"
    fi
    chmod +x "$target"

    shell_rc="$user_home/.bashrc"
    [[ "$SHELL" =~ zsh ]] && shell_rc="$user_home/.zshrc"
    if [ -f "$shell_rc" ] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$shell_rc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
        log_success "Added $install_path to PATH in $shell_rc"
    fi

    log_success "0xdocker installed successfully to $target"
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
    
    log_success "System requirements check completed"
}

function optimize_dns() {
    log_info "Starting DNS optimization process..."
    
    cd "$SCRIPT_DIR"
    
    # Run DNS optimization with Docker connectivity focus
    echo ""
    log_info "Testing DNS servers for Docker connectivity..."
    echo "This will test each DNS server's ability to connect to Docker download servers."
    echo ""
    
    if run_embedded_selector dns; then
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
    
    # Run registry mirror optimization
    echo ""
    log_info "Testing Docker registry mirrors for optimal performance..."
    echo "This will test all available mirrors and let you choose the best one..."
    echo ""
    
    # Run the registry selector
    if run_embedded_selector registry; then
        log_success "Docker registry mirror optimization completed!"
    else
        log_warning "Registry mirror optimization failed or was skipped"
        log_info "You can run it manually later with: sudo ./main.sh registry"
    fi
    
    echo ""
    log_info "Registry optimization process finished"
}

function run_docker_mirror_registry() {
    log_info "Starting Docker Mirror Registry Selector..."
    
    cd "$SCRIPT_DIR"
    
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
    
    # Run the registry selector with sudo
    echo ""
    log_info "Launching Docker Mirror Registry Selector..."
    echo "This will test all available Docker registry mirrors and let you choose the best one."
    echo ""
    
    if sudo "$0" registry; then
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

    # Set DISTRO based on ID or ID_LIKE
    if [[ "$DISTRO_ID" == "ubuntu" ]]; then
        DISTRO="ubuntu"
    elif [[ "$DISTRO_ID" == "debian" ]]; then
        DISTRO="debian"
    elif [[ "$DISTRO_ID" == "manjaro" ]] || [[ "$DISTRO_ID" == "arch" ]] || [[ "$ID_LIKE" == "arch" ]]; then
        DISTRO="arch"
    else
        log_error "Unsupported distribution: $DISTRO_ID ($DISTRO_NAME)"
        echo "This script only supports Debian, Ubuntu, and Arch-based distributions."
        exit 1
    fi

    log_info "Detected distribution: $DISTRO ($DISTRO_NAME)"

    if [ "$DISTRO" = "arch" ]; then
        log_info "Installing Docker for Arch Linux..."
        pacman -Syu --noconfirm docker docker-compose

        log_info "Starting and enabling Docker service..."
        systemctl start docker
        systemctl enable docker

        if [ "$SUDO_USER" ]; then
            log_info "Adding user $SUDO_USER to docker group..."
            usermod -aG docker "$SUDO_USER"
            log_warning "Please log out and back in for group changes to take effect"
        fi

        log_info "Verifying Docker installation..."
        if docker --version && docker compose version; then
            log_success "Docker installation completed successfully!"
            docker --version
            docker compose version
            optimize_docker_registry
        else
            log_error "Docker installation verification failed"
            exit 1
        fi
        return
    fi

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
    
    install_0xdocker_executable

    # Add ~/.local/bin to current PATH if not already there
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        export PATH="$HOME/.local/bin:$PATH"
        log_info "Added ~/.local/bin to current session PATH"
    fi

    hash -r 2>/dev/null || true

    if [ -f "$HOME/.local/bin/0xdocker" ]; then
        log_info "Launching 0xdocker management tool..."
        "$HOME/.local/bin/0xdocker"
    else
        log_warning "0xdocker executable not found after installation"
        log_info "Launching management tool from embedded script..."
        run_embedded_0xdocker
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
        if command -v apt-get &> /dev/null; then
            apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras || true
        elif command -v pacman &> /dev/null; then
            pacman -Rns --noconfirm docker docker-compose || true
        fi
        
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
        install_0xdocker_executable
        
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
        echo "Choose what you want to do:"
        echo ""
        echo "  🚀 Setup"
        echo "    1) Full setup: DNS + Docker + 0xDocker + Registry mirror"
        echo "    2) Install Docker only"
        echo ""
        echo "  🌐 Optimization"
        echo "    3) Optimize DNS for Docker"
        echo "    4) Configure Docker registry mirror"
        echo ""
        echo "  🛠️  Tools"
        echo "    5) Open 0xDocker management tool"
        echo "    6) Install 0xDocker as a system service"
        echo ""
        echo "  🧹 Maintenance"
        echo "    7) Uninstall Docker"
        echo "    8) Remove 0xDocker tool and service"
        echo ""
        echo "    9) Exit"
        echo ""
        read -p "Enter your choice [1-9]: " choice

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
                echo "  • Run: sudo ./main.sh registry"
                echo "  • Or use menu option 4"
                read -p "Press Enter to continue..."
                ;;
            2)
                log_info "Starting Docker installation..."
                check_requirements
                install_docker
                read -p "Press Enter to continue..."
                ;;
            3)
                log_info "Starting DNS optimization..."
                check_requirements
                optimize_dns
                read -p "Press Enter to continue..."
                ;;
            4)
                run_docker_mirror_registry
                read -p "Press Enter to continue..."
                ;;
            5)
                launch_management_tool
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

# Dispatch embedded tools when this single script is reused as a command.
if [ "$(basename "$0")" = "0xdocker" ]; then
    run_embedded_0xdocker "$@"
    exit $?
fi

if [ "$1" = "dns" ]; then
    run_embedded_selector dns
    exit $?
elif [ "$1" = "registry" ]; then
    run_embedded_selector registry
    exit $?
elif [ "$1" = "--0xdocker" ]; then
    shift
    run_embedded_0xdocker "$@"
    exit $?
fi

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
exit $?

__SELECTORS_SH_BEGIN__
#!/bin/bash

set -e

SCRIPT_DIR="${DOCKER4IRAN_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
DNS_CONFIG_PATH="$SCRIPT_DIR/conf/dns.json"
REGISTRY_CONFIG_PATH="$SCRIPT_DIR/conf/docker.json"
DAEMON_JSON_PATH="/etc/docker/daemon.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

function ensure_command() {
    local command_name="$1"
    local debian_package="$2"
    local arch_package="$3"

    if command -v "$command_name" >/dev/null 2>&1; then
        return 0
    fi

    log_warning "$command_name is not installed. Trying to install it..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y "$debian_package"
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Syu --noconfirm "$arch_package"
    else
        log_error "Could not install $command_name. Unsupported package manager."
        return 1
    fi
}

function json_value() {
    sed -E 's/^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*"?([^",}]*)"?[,]?[[:space:]]*$/\1/'
}

function load_dns_servers() {
    if [ ! -f "$DNS_CONFIG_PATH" ]; then
        log_error "DNS config file not found: $DNS_CONFIG_PATH"
        return 1
    fi

    awk '
        /^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*\{/ {
            current_name=$0
            gsub(/^[[:space:]]*"/, "", current_name)
            gsub(/"[[:space:]]*:[[:space:]]*\{[[:space:]]*$/, "", current_name)
        }
        /"primary"/ {
            primary=$0
            gsub(/^[[:space:]]*"primary"[[:space:]]*:[[:space:]]*"/, "", primary)
            gsub(/"[,]?[[:space:]]*$/, "", primary)
        }
        /"secondary"/ {
            secondary=$0
            gsub(/^[[:space:]]*"secondary"[[:space:]]*:[[:space:]]*"/, "", secondary)
            gsub(/"[,]?[[:space:]]*$/, "", secondary)
            if (current_name != "" && primary != "") {
                print current_name "|" primary "|" secondary
            }
            primary=""
            secondary=""
        }
    ' "$DNS_CONFIG_PATH"
}

function load_registry_mirrors() {
    if [ ! -f "$REGISTRY_CONFIG_PATH" ]; then
        log_error "Registry config file not found: $REGISTRY_CONFIG_PATH"
        return 1
    fi

    awk '
        /^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*\{/ {
            current_name=$0
            gsub(/^[[:space:]]*"/, "", current_name)
            gsub(/"[[:space:]]*:[[:space:]]*\{[[:space:]]*$/, "", current_name)
        }
        /"mirror"/ {
            mirror=$0
            gsub(/^[[:space:]]*"mirror"[[:space:]]*:[[:space:]]*"/, "", mirror)
            gsub(/"[,]?[[:space:]]*$/, "", mirror)
        }
        /"insecure"/ {
            insecure=$0
            gsub(/^[[:space:]]*"insecure"[[:space:]]*:[[:space:]]*/, "", insecure)
            gsub(/[,]?[[:space:]]*$/, "", insecure)
        }
        /"description"/ {
            description=$0
            gsub(/^[[:space:]]*"description"[[:space:]]*:[[:space:]]*"/, "", description)
            gsub(/"[,]?[[:space:]]*$/, "", description)
            if (current_name != "" && mirror != "") {
                print current_name "|" mirror "|" insecure "|" description
            }
            mirror=""
            insecure=""
            description=""
        }
    ' "$REGISTRY_CONFIG_PATH"
}

function now_ms() {
    date +%s%3N
}

function test_dns_resolution() {
    local dns_server="$1"
    local domain="$2"
    local start_time
    local end_time
    local elapsed_ms

    start_time="$(now_ms)"
    if timeout 4 nslookup "$domain" "$dns_server" >/dev/null 2>&1; then
        end_time="$(now_ms)"
        elapsed_ms=$((end_time - start_time))
        echo "1|$elapsed_ms"
    else
        echo "0|999999"
    fi
}

function calculate_dns_result() {
    local name="$1"
    local primary="$2"
    local secondary="$3"
    local test_domains=("google.com" "github.com" "docker.com" "ubuntu.com")
    local docker_domains=("download.docker.com" "registry-1.docker.io" "auth.docker.io")
    local success_count=0
    local total_time=0
    local docker_success_count=0
    local docker_total_time=0
    local result
    local success
    local elapsed
    local domain

    echo "🔍 Testing $name ($primary)..." >&2

    for domain in "${test_domains[@]}"; do
        result="$(test_dns_resolution "$primary" "$domain")"
        success="${result%%|*}"
        elapsed="${result##*|}"
        if [ "$success" = "1" ]; then
            success_count=$((success_count + 1))
            total_time=$((total_time + elapsed))
        fi
    done

    for domain in "${docker_domains[@]}"; do
        result="$(test_dns_resolution "$primary" "$domain")"
        success="${result%%|*}"
        elapsed="${result##*|}"
        if [ "$success" = "1" ]; then
            docker_success_count=$((docker_success_count + 1))
            docker_total_time=$((docker_total_time + elapsed))
        fi
    done

    if [ "$success_count" -eq 0 ]; then
        echo "$name|$primary|$secondary|0|999999|0|999999|0"
        return
    fi

    local avg_time=$((total_time / success_count))
    local success_rate=$((success_count * 100 / ${#test_domains[@]}))
    local docker_avg_time=999999
    local docker_success_rate=0
    local docker_working=0

    if [ "$docker_success_count" -gt 0 ]; then
        docker_avg_time=$((docker_total_time / docker_success_count))
        docker_success_rate=$((docker_success_count * 100 / ${#docker_domains[@]}))
        if [ "$docker_success_rate" -ge 66 ]; then
            docker_working=1
        fi
    fi

    echo "$name|$primary|$secondary|$success_rate|$avg_time|$docker_success_rate|$docker_avg_time|$docker_working"
}

function is_systemd_resolved_active() {
    command -v resolvectl >/dev/null 2>&1 && resolvectl status >/dev/null 2>&1
}

function apply_dns_systemd_resolved() {
    local primary_dns="$1"
    local secondary_dns="$2"
    local conf_dir="/etc/systemd/resolved.conf.d"
    local conf_file="$conf_dir/99-docker4iran-dns.conf"
    local tmp_file="/tmp/99-docker4iran-dns.conf"
    local dns_servers="$primary_dns"

    if [ -n "$secondary_dns" ]; then
        dns_servers="$dns_servers $secondary_dns"
    fi

    printf "[Resolve]\nDNS=%s\n" "$dns_servers" > "$tmp_file"
    sudo mkdir -p "$conf_dir"
    sudo cp "$tmp_file" "$conf_file"
    rm -f "$tmp_file"
    sudo systemctl restart systemd-resolved
}

function apply_dns_resolv_conf() {
    local primary_dns="$1"
    local secondary_dns="$2"
    local tmp_file="/tmp/resolv.conf.docker4iran"

    {
        echo "nameserver $primary_dns"
        if [ -n "$secondary_dns" ]; then
            echo "nameserver $secondary_dns"
        fi
    } > "$tmp_file"

    sudo cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true
    sudo cp "$tmp_file" /etc/resolv.conf
    rm -f "$tmp_file"
}

function run_dns_selector() {
    ensure_command nslookup dnsutils bind >/dev/null || return 1

    echo "🔧 Docker Installation DNS Selector"
    echo "=================================================="
    echo "🧪 DNS SERVER PERFORMANCE TEST (Docker Installation Focus)"
    echo "======================================================================"

    local results_file
    results_file="$(mktemp)"
    while IFS='|' read -r name primary secondary; do
        [ -z "$name" ] && continue
        calculate_dns_result "$name" "$primary" "$secondary" >> "$results_file"
    done < <(load_dns_servers)

    local working_file
    working_file="$(mktemp)"
    awk -F'|' '$4 >= 50 {print ($8 == 1 ? 0 : 1) "|" $7 "|" $5 "|" $0}' "$results_file" | sort -t'|' -k1,1n -k2,2n -k3,3n > "$working_file"

    if [ ! -s "$working_file" ]; then
        log_error "No working DNS servers found."
        rm -f "$results_file" "$working_file"
        return 1
    fi

    echo
    echo "📊 DNS SERVER TEST RESULTS:"
    echo "======================================================================"
    printf "%-3s %-14s %-18s %-24s %-15s\n" "#" "Name" "General" "Docker Connectivity" "IP Address"
    echo "----------------------------------------------------------------------"

    local index=1
    local names=()
    local primaries=()
    local secondaries=()
    while IFS='|' read -r _sort_docker _sort_docker_time _sort_general_time name primary secondary success_rate avg_time docker_success_rate docker_avg_time docker_working; do
        names+=("$name")
        primaries+=("$primary")
        secondaries+=("$secondary")
        local general_status="$((avg_time / 1000)).$((avg_time % 1000))s (${success_rate}%)"
        local docker_status="❌ Failed"
        if [ "$docker_working" = "1" ]; then
            docker_status="✅ $((docker_avg_time / 1000)).$((docker_avg_time % 1000))s (${docker_success_rate}%)"
        fi
        printf "%-3s %-14s %-18s %-24s %-15s\n" "$index" "$name" "$general_status" "$docker_status" "$primary"
        index=$((index + 1))
    done < "$working_file"

    echo
    echo "🎯 SELECT DNS SERVER:"
    local choice
    while true; do
        read -p "Enter number (1-${#names[@]}) or 'q' to quit: " choice
        choice="$(echo "$choice" | tr '[:upper:]' '[:lower:]')"
        if [ "$choice" = "q" ]; then
            rm -f "$results_file" "$working_file"
            return 1
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#names[@]}" ]; then
            break
        fi
        log_error "Please enter a valid number."
    done

    local selected_index=$((choice - 1))
    local selected_name="${names[$selected_index]}"
    local selected_primary="${primaries[$selected_index]}"
    local selected_secondary="${secondaries[$selected_index]}"

    echo
    echo "✅ SELECTED: $selected_name ($selected_primary)"
    read -p "🤔 Apply DNS settings: $selected_primary${selected_secondary:+ & $selected_secondary}? (y/N): " confirm
    confirm="$(echo "$confirm" | tr '[:upper:]' '[:lower:]')"

    if [ "$confirm" = "y" ] || [ "$confirm" = "yes" ]; then
        if is_systemd_resolved_active; then
            log_info "systemd-resolved detected. Applying DNS settings via resolvectl config..."
            apply_dns_systemd_resolved "$selected_primary" "$selected_secondary"
        else
            log_info "Applying DNS settings via /etc/resolv.conf..."
            apply_dns_resolv_conf "$selected_primary" "$selected_secondary"
        fi
        log_success "DNS settings applied successfully."
    else
        log_warning "DNS settings not applied. Using system defaults."
    fi

    rm -f "$results_file" "$working_file"
}

function normalize_registry_url() {
    local mirror="$1"
    if [[ "$mirror" =~ ^https?:// ]]; then
        echo "${mirror%/}"
    else
        echo "https://${mirror%/}"
    fi
}

function test_registry_endpoint() {
    local url="$1"
    local path="$2"
    local output
    local status
    local response_time

    output="$(curl -k -L -s -o /dev/null -w "%{http_code}|%{time_total}" --max-time 15 "$url$path" 2>/dev/null || true)"
    status="${output%%|*}"
    response_time="${output##*|}"

    case "$status" in
        200|401|404)
            echo "1|$response_time"
            ;;
        *)
            echo "0|999999"
            ;;
    esac
}

function run_registry_tests() {
    local results_file="$1"
    local name
    local mirror
    local insecure
    local description

    while IFS='|' read -r name mirror insecure description; do
        [ -z "$name" ] && continue
        local test_url
        local connectivity
        local hub
        local connectivity_success
        local connectivity_time
        local hub_success
        local hub_time
        local score="999999"
        local status="Connection Failed"

        test_url="$(normalize_registry_url "$mirror")"
        echo "🔍 Testing $name: $mirror"
        [ -n "$description" ] && echo "   📝 $description"

        connectivity="$(test_registry_endpoint "$test_url" "/v2/")"
        connectivity_success="${connectivity%%|*}"
        connectivity_time="${connectivity##*|}"

        if [ "$connectivity_success" = "1" ]; then
            echo "  ✅ Connectivity: ${connectivity_time}s"
            hub="$(test_registry_endpoint "$test_url" "/v2/library/hello-world/manifests/latest")"
            hub_success="${hub%%|*}"
            hub_time="${hub##*|}"
            if [ "$hub_success" = "1" ]; then
                echo "  ✅ Docker Hub access: ${hub_time}s"
                score="$(awk "BEGIN {printf \"%.3f\", $connectivity_time + ($hub_time * 1.5)}")"
                status="Working"
            else
                echo "  ⚠️  Docker Hub access failed"
                status="Hub Access Failed"
            fi
        else
            echo "  ❌ Connectivity failed"
        fi

        echo "$score|$name|$mirror|$insecure|$description|$connectivity_success|$connectivity_time|$hub_success|$hub_time|$status" >> "$results_file"
        echo
    done < <(load_registry_mirrors)
}

function write_daemon_json() {
    local mirror="$1"
    local insecure="$2"
    local backup_file

    sudo mkdir -p "$(dirname "$DAEMON_JSON_PATH")"
    if [ -f "$DAEMON_JSON_PATH" ]; then
        backup_file="${DAEMON_JSON_PATH}.docker4iran.$(date +%Y%m%d%H%M%S).backup"
        sudo cp "$DAEMON_JSON_PATH" "$backup_file"
        log_warning "Existing daemon.json backed up to $backup_file"
    fi

    local tmp_file
    tmp_file="$(mktemp)"
    if [ "$insecure" = "true" ]; then
        cat > "$tmp_file" <<EOF
{
  "registry-mirrors": [
    "$mirror"
  ],
  "insecure-registries": [
    "$mirror"
  ]
}
EOF
    else
        cat > "$tmp_file" <<EOF
{
  "registry-mirrors": [
    "$mirror"
  ]
}
EOF
    fi

    sudo cp "$tmp_file" "$DAEMON_JSON_PATH"
    rm -f "$tmp_file"
}

function configure_registry_mirror() {
    local name="$1"
    local mirror="$2"
    local insecure="$3"

    if [ "$(id -u)" -ne 0 ]; then
        log_error "This action requires root privileges. Run: sudo ./main.sh registry"
        return 1
    fi

    write_daemon_json "$mirror" "$insecure"
    systemctl restart docker
    sleep 5

    if docker info >/dev/null 2>&1; then
        log_success "Docker daemon configured successfully."
        echo "🎉 Now using registry mirror: $name ($mirror)"
        return 0
    fi

    log_error "Docker failed to start properly after registry configuration."
    return 1
}

function run_registry_selector() {
    ensure_command curl curl curl >/dev/null || return 1

    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
        log_error "Docker is not installed or not running."
        return 1
    fi

    echo "🐳 Interactive Docker Registry Mirror Selector"
    echo "=================================================="

    local results_file
    results_file="$(mktemp)"
    run_registry_tests "$results_file"

    local working_file
    working_file="$(mktemp)"
    awk -F'|' '$10 == "Working" {print}' "$results_file" | sort -t'|' -k1,1n > "$working_file"

    if [ ! -s "$working_file" ]; then
        log_error "No working registry mirrors found."
        rm -f "$results_file" "$working_file"
        return 1
    fi

    echo "📊 DOCKER REGISTRY MIRROR TEST RESULTS"
    echo "============================================================"
    printf "%-3s %-14s %-34s %-10s %-10s %-10s\n" "#" "Registry" "Mirror" "Conn(s)" "Hub(s)" "Score"
    echo "--------------------------------------------------------------------------------"

    local index=1
    local names=()
    local mirrors=()
    local insecures=()
    while IFS='|' read -r score name mirror insecure description connectivity_success connectivity_time hub_success hub_time status; do
        names+=("$name")
        mirrors+=("$mirror")
        insecures+=("$insecure")
        printf "%-3s %-14s %-34s %-10s %-10s %-10s\n" "$index" "$name" "$mirror" "$connectivity_time" "$hub_time" "$score"
        [ -n "$description" ] && echo "    └─ $description"
        index=$((index + 1))
    done < "$working_file"

    echo
    local choice
    while true; do
        echo "🤔 Choose a registry mirror to configure:"
        echo "   1-${#names[@]}: Select from the working mirrors above"
        echo "   0: Skip configuration"
        echo "   q: Quit without changes"
        read -p "Enter your choice: " choice
        choice="$(echo "$choice" | tr '[:upper:]' '[:lower:]')"

        if [ "$choice" = "q" ] || [ "$choice" = "0" ]; then
            rm -f "$results_file" "$working_file"
            return 1
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#names[@]}" ]; then
            break
        fi
        log_error "Please enter a valid choice."
    done

    local selected_index=$((choice - 1))
    local selected_name="${names[$selected_index]}"
    local selected_mirror="${mirrors[$selected_index]}"
    local selected_insecure="${insecures[$selected_index]}"

    echo
    echo "✅ You selected: $selected_name ($selected_mirror)"
    read -p "🔄 Confirm configuration? (y/N): " confirm
    confirm="$(echo "$confirm" | tr '[:upper:]' '[:lower:]')"

    if [ "$confirm" = "y" ] || [ "$confirm" = "yes" ]; then
        configure_registry_mirror "$selected_name" "$selected_mirror" "$selected_insecure"
    else
        log_warning "Registry configuration cancelled."
        rm -f "$results_file" "$working_file"
        return 1
    fi

    rm -f "$results_file" "$working_file"
}

function show_usage() {
    echo "Usage: $0 {dns|registry}"
}

case "${1:-}" in
    dns)
        run_dns_selector
        ;;
    registry)
        run_registry_selector
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

__SELECTORS_SH_END__

__ZEROXDOCKER_SH_BEGIN__
#!/bin/bash

# =============================================================================
# 0xDOCKER MANAGEMENT TOOL
# =============================================================================
# Docker management and monitoring tool with self-installation capability
# This script provides comprehensive Docker management without installation
# =============================================================================

set -e

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================
INSTALL_PATH="$HOME/.local/bin"
TARGET="$INSTALL_PATH/0xdocker"
LOG_FILE="$HOME/.local/share/0xdocker.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================
# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

function log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

function log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

function log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# SELF-INSTALL SECTION
# =============================================================================
if [[ "${DOCKER4IRAN_EMBEDDED:-0}" != "1" && "$0" != "$TARGET" ]]; then
    log_info "Installing 0xdocker to $TARGET..."
    mkdir -p "$INSTALL_PATH"
    cp "$0" "$TARGET"
    chmod +x "$TARGET"

    if ! echo "$PATH" | grep -q "$INSTALL_PATH"; then
        SHELL_RC="$HOME/.bashrc"
        [[ "$SHELL" =~ zsh ]] && SHELL_RC="$HOME/.zshrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
        log_success "Added $INSTALL_PATH to PATH in $SHELL_RC"
        echo "➡️  Please restart your terminal or run: source $SHELL_RC"
    fi

    log_success "0xdocker installed! Now you can just run: 0xdocker"
    exit 0
fi

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
function check_docker_status() {
    if docker info >/dev/null 2>&1; then
        echo -e "\e[32m✅ Docker is running\e[0m"
        return 0
    else
        echo -e "\e[31m❌ Docker is NOT running\e[0m"
        return 1
    fi
}

function check_docker_compose_status() {
    if docker compose version >/dev/null 2>&1; then
        echo -e "\e[32m✅ Docker Compose is available\e[0m"
        return 0
    else
        echo -e "\e[31m❌ Docker Compose is NOT available\e[0m"
        return 1
    fi
}

function show_header() {
    clear
    echo "------------------------------------------------------------"
    echo " dP\"Yb  Yb  dP 8888b.   dP\"Yb   dP\"\"b8 88  dP 888888 88\"\"Yb"
    echo "dP   Yb  YbdP   8I  Yb dP   Yb dP   \`\" 88odP  88__   88__dP"
    echo "Yb   dP  dPYb   8I  dY Yb   dP Yb      88\"Yb  88\"\"   88\"Yb"
    echo " YbodP  dP  Yb 8888Y\"   YbodP   YboodP 88  Yb 888888 88  Yb"
    echo "------------------------------------------------------------"
    echo "           0xDocker Management Tool - by 0xAmirreza"
    echo "------------------------------------------------------------"
    check_docker_status
    check_docker_compose_status
}

function check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed on this system!"
        echo "Please install Docker first before using this management tool."
        echo "Visit https://docs.docker.com/get-docker/ for installation instructions."
        exit 1
    fi
}

# =============================================================================
# DOCKER MANAGEMENT FUNCTIONS
# =============================================================================
function show_containers() {
    echo -e "\n=== Docker Containers ==="
    if docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" 2>/dev/null; then
        echo -e "\nContainer resource usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || true
    else
        log_warning "No containers found or Docker not accessible"
    fi
}

function show_images() {
    echo -e "\n=== Docker Images ==="
    if docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedSince}}" 2>/dev/null; then
        echo -e "\nTotal images: $(docker images -q | wc -l)"
        echo "Total size: $(docker images --format "{{.Size}}" | sed 's/[^0-9.]*//g' | awk '{sum+=$1} END {print sum "MB"}' 2>/dev/null || echo "Unknown")"
    else
        log_warning "No images found or Docker not accessible"
    fi
}

function show_volumes() {
    echo -e "\n=== Docker Volumes ==="
    if docker volume ls 2>/dev/null; then
        echo -e "\nVolume details:"
        docker system df -v | grep -A 20 "Local Volumes" 2>/dev/null || true
    else
        log_warning "No volumes found or Docker not accessible"
    fi
}

function show_networks() {
    echo -e "\n=== Docker Networks ==="
    if docker network ls 2>/dev/null; then
        echo -e "\nNetwork details:"
        for network in $(docker network ls --format "{{.Name}}" | grep -v "bridge\|host\|none"); do
            echo "Network: $network"
            docker network inspect $network --format "  Containers: {{range .Containers}}{{.Name}} {{end}}" 2>/dev/null || true
        done
    else
        log_warning "No networks found or Docker not accessible"
    fi
}

function show_docker_compose_projects() {
    echo -e "\n=== Docker Compose Projects ==="
    if docker ps --format "{{.Names}}" 2>/dev/null | grep -E '[-_][0-9]+$' | cut -d'-' -f1 | cut -d'_' -f1 | sort | uniq -c; then
        echo ""
        echo -e "\n=== Active Compose Services ==="
        docker compose ls 2>/dev/null || echo "No active compose projects found"
    else
        echo "No Docker Compose projects detected"
    fi
}

function show_system_info() {
    echo -e "\n=== Docker System Information ==="
    docker system info 2>/dev/null | head -20
    echo -e "\n=== Docker Disk Usage ==="
    docker system df 2>/dev/null || log_warning "Could not retrieve Docker disk usage"
}

function show_all() {
    show_containers
    show_images
    show_volumes
    show_networks
    show_docker_compose_projects
    show_system_info
    show_cache_and_data
}

function show_cache_and_data() {
    CACHE_DIR="$HOME/.docker_cache"
    DATA_DIR="$HOME/.docker_data"

    echo -e "\n=== Docker Custom Cache ==="
    if [[ -d "$CACHE_DIR" ]]; then
        du -sh "$CACHE_DIR"
    else
        echo "No cache directory found."
    fi

    echo -e "\n=== Docker Custom Data ==="
    if [[ -d "$DATA_DIR" ]]; then
        du -sh "$DATA_DIR"
    else
        echo "No data directory found."
    fi
    
    echo -e "\n=== Docker System Cache ==="
    echo "Build cache: $(docker system df | grep "Build Cache" | awk '{print $3}' || echo "Unknown")"
}

function container_management() {
    echo -e "\n=== Container Management ==="
    echo "1. Start all stopped containers"
    echo "2. Stop all running containers"
    echo "3. Restart all containers"
    echo "4. Remove stopped containers"
    echo "5. Interactive container shell"
    echo "6. View container logs"
    echo "7. Back to main menu"
    
    read -p "Choose an option: " choice
    case $choice in
        1)
            log_info "Starting all stopped containers..."
            docker start $(docker ps -a -q --filter "status=exited") 2>/dev/null || log_info "No stopped containers to start"
            ;;
        2)
            log_info "Stopping all running containers..."
            docker stop $(docker ps -q) 2>/dev/null || log_info "No running containers to stop"
            ;;
        3)
            log_info "Restarting all containers..."
            docker restart $(docker ps -a -q) 2>/dev/null || log_info "No containers to restart"
            ;;
        4)
            log_info "Removing stopped containers..."
            docker container prune -f
            ;;
        5)
            docker ps --format "table {{.Names}}\t{{.Status}}"
            read -p "Enter container name to access: " container_name
            if docker exec -it "$container_name" /bin/bash 2>/dev/null; then
                :
            elif docker exec -it "$container_name" /bin/sh 2>/dev/null; then
                :
            else
                log_error "Could not access container $container_name"
            fi
            ;;
        6)
            container_logs_viewer
            ;;
        7) return ;;
        *) log_warning "Invalid option" ;;
    esac
}

function view_live_logs() {
    local container_name="$1"
    local extra_flags="$2"  # For timestamps (-t)
    
    echo -e "\n📋 Starting live logs for container: $container_name"
    echo "Press Ctrl+C to stop following logs and return to menu..."
    echo "=========================================="
    
    # Set trap to handle Ctrl+C gracefully
    trap 'echo -e "\n🛑 Stopping live logs..."; return 0' INT
    
    # Run docker logs with the provided flags
    docker logs -f $extra_flags "$container_name"
    
    # Remove trap after logs finish
    trap - INT
}

function container_logs_viewer() {
    echo -e "\n=== Container Logs Viewer ==="
    
    # Get all containers (running and stopped)
    local containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null)
    
    if [ -z "$containers" ]; then
        log_warning "No containers found"
        return
    fi
    
    echo "Available containers:"
    echo "===================="
    local i=1
    local container_array=()
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            local status=$(docker ps --filter "name=^${container}$" --format "{{.Status}}" 2>/dev/null)
            if [ -n "$status" ]; then
                echo "$i. $container (Running: $status)"
            else
                echo "$i. $container (Stopped)"
            fi
            container_array+=("$container")
            ((i++))
        fi
    done <<< "$containers"
    
    echo ""
    read -p "Enter container number or name: " choice
    
    # Handle numeric choice
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        if [ "$choice" -ge 1 ] && [ "$choice" -le "${#container_array[@]}" ]; then
            local selected_container="${container_array[$((choice-1))]}"
        else
            log_error "Invalid container number"
            return
        fi
    else
        # Handle name choice
        local selected_container="$choice"
        # Verify container exists
        if ! docker ps -a --format "{{.Names}}" | grep -q "^${selected_container}$"; then
            log_error "Container '$selected_container' not found"
            return
        fi
    fi
    
    echo ""
    echo "=== Log Options for Container: $selected_container ==="
    echo "1. Live logs (follow mode) - Press Ctrl+C to stop"
    echo "2. Last 50 lines"
    echo "3. Last 100 lines"
    echo "4. Last 500 lines"
    echo "5. Custom number of lines"
    echo "6. Logs with timestamps"
    echo "7. Live logs with timestamps"
    echo "8. Back to container management"
    
    read -p "Choose log option: " log_choice
    
    case $log_choice in
        1)
            view_live_logs "$selected_container"
            ;;
        2)
            echo -e "\n📋 Last 50 lines for container: $selected_container"
            echo "=========================================="
            docker logs --tail 50 "$selected_container"
            ;;
        3)
            echo -e "\n📋 Last 100 lines for container: $selected_container"
            echo "=========================================="
            docker logs --tail 100 "$selected_container"
            ;;
        4)
            echo -e "\n📋 Last 500 lines for container: $selected_container"
            echo "=========================================="
            docker logs --tail 500 "$selected_container"
            ;;
        5)
            read -p "Enter number of lines to show: " lines
            if [[ "$lines" =~ ^[0-9]+$ ]]; then
                echo -e "\n📋 Last $lines lines for container: $selected_container"
                echo "=========================================="
                docker logs --tail "$lines" "$selected_container"
            else
                log_error "Invalid number of lines"
            fi
            ;;
        6)
            echo -e "\n📋 Last 50 lines with timestamps for container: $selected_container"
            echo "=========================================="
            docker logs --tail 50 -t "$selected_container"
            ;;
        7)
            view_live_logs "$selected_container" "-t"
            ;;
        8)
            return
            ;;
        *)
            log_warning "Invalid option"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

function image_management() {
    echo -e "\n=== Image Management ==="
    echo "1. Pull image"
    echo "2. Remove unused images"
    echo "3. Remove all images"
    echo "4. Search Docker Hub"
    echo "5. Image history"
    echo "6. Back to main menu"
    
    read -p "Choose an option: " choice
    case $choice in
        1)
            read -p "Enter image name (e.g., nginx:latest): " image_name
            docker pull "$image_name"
            ;;
        2)
            log_info "Removing unused images..."
            docker image prune -f
            ;;
        3)
            echo -e "\n⚠️  This will remove ALL images!"
            read -p "Are you sure? Type 'yes' to continue: " confirm
            if [[ "$confirm" == "yes" ]]; then
                docker rmi $(docker images -q) 2>/dev/null || log_info "No images to remove"
            fi
            ;;
        4)
            read -p "Enter search term: " search_term
            docker search "$search_term"
            ;;
        5)
            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}"
            read -p "Enter image name: " image_name
            docker history "$image_name"
            ;;
        6) return ;;
        *) log_warning "Invalid option" ;;
    esac
}

function remove_all() {
    echo -e "\n⚠️  This will remove ALL Docker containers, images, volumes, unused networks, and custom cache/data."
    read -p "Are you sure? Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
        log_info "Starting complete Docker cleanup..."
        
        echo -e "\nStopping all containers..."
        docker stop $(docker ps -q) 2>/dev/null || log_info "No running containers to stop"

        echo "Removing all containers..."
        docker rm $(docker ps -a -q) 2>/dev/null || log_info "No containers to remove"

        echo "Removing all images..."
        docker rmi $(docker images -q) 2>/dev/null || log_info "No images to remove"

        echo "Removing all volumes..."
        docker volume rm $(docker volume ls -q) 2>/dev/null || log_info "No volumes to remove"

        echo "Pruning unused networks..."
        docker network prune -f

        echo "Removing custom cache/data folders..."
        rm -rf "$HOME/.docker_cache" "$HOME/.docker_data"

        log_success "All Docker resources removed."
    else
        log_info "Operation cancelled."
    fi
}

function full_cleanup() {
    echo -e "\n⚠️  This will perform a full Docker system cleanup, including dangling images, build cache, and unused resources."
    read -p "Are you sure you want to continue? Type 'yes' to continue: " confirm
    if [[ "$confirm" == "yes" ]]; then
        log_info "Starting full Docker cleanup..."
        
        echo -e "\n🧽 Removing dangling images..."
        docker image prune -f

        echo -e "\n🧹 Pruning unused Docker system data..."
        docker system prune -a --volumes -f

        echo -e "\n🔨 Removing builder cache..."
        docker builder prune -a -f

        log_success "Full Docker cleanup completed."
        
        echo -e "\nSpace reclaimed:"
        docker system df
    else
        log_info "Operation cancelled."
    fi
}

function docker_compose_management() {
    echo -e "\n=== Docker Compose Management ==="
    echo "1. List all compose projects"
    echo "2. Start compose project"
    echo "3. Stop compose project"
    echo "4. Restart compose project"
    echo "5. View compose project logs"
    echo "6. Remove compose project"
    echo "7. Back to main menu"
    
    read -p "Choose an option: " choice
    case $choice in
        1)
            docker compose ls
            ;;
        2)
            read -p "Enter path to docker-compose.yml directory: " compose_path
            if [[ -f "$compose_path/docker-compose.yml" ]] || [[ -f "$compose_path/compose.yml" ]]; then
                cd "$compose_path" && docker compose up -d
            else
                log_error "No docker-compose.yml or compose.yml found in $compose_path"
            fi
            ;;
        3)
            read -p "Enter path to docker-compose.yml directory: " compose_path
            if [[ -f "$compose_path/docker-compose.yml" ]] || [[ -f "$compose_path/compose.yml" ]]; then
                cd "$compose_path" && docker compose down
            else
                log_error "No docker-compose.yml or compose.yml found in $compose_path"
            fi
            ;;
        4)
            read -p "Enter path to docker-compose.yml directory: " compose_path
            if [[ -f "$compose_path/docker-compose.yml" ]] || [[ -f "$compose_path/compose.yml" ]]; then
                cd "$compose_path" && docker compose restart
            else
                log_error "No docker-compose.yml or compose.yml found in $compose_path"
            fi
            ;;
        5)
            read -p "Enter path to docker-compose.yml directory: " compose_path
            if [[ -f "$compose_path/docker-compose.yml" ]] || [[ -f "$compose_path/compose.yml" ]]; then
                cd "$compose_path" && docker compose logs -f
            else
                log_error "No docker-compose.yml or compose.yml found in $compose_path"
            fi
            ;;
        6)
            read -p "Enter path to docker-compose.yml directory: " compose_path
            echo -e "\n⚠️  This will remove the compose project and its volumes!"
            read -p "Are you sure? Type 'yes' to continue: " confirm
            if [[ "$confirm" == "yes" ]]; then
                if [[ -f "$compose_path/docker-compose.yml" ]] || [[ -f "$compose_path/compose.yml" ]]; then
                    cd "$compose_path" && docker compose down -v
                else
                    log_error "No docker-compose.yml or compose.yml found in $compose_path"
                fi
            fi
            ;;
        7) return ;;
        *) log_warning "Invalid option" ;;
    esac
}

# =============================================================================
# MAIN MENU SYSTEM
# =============================================================================
function show_main_menu() {
    show_header
    
    # Check if Docker is installed
    if ! check_docker_status >/dev/null 2>&1; then
        echo -e "\n${RED}❌ Docker is not running or not installed!${NC}"
        echo "Please ensure Docker is installed and running before using this tool."
        echo ""
        echo "1. Try to start Docker service"
        echo "2. Check Docker installation"
        echo "3. Exit"
        
        read -p "Choose an option: " choice
        case $choice in
            1)
                log_info "Attempting to start Docker service..."
                if sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null; then
                    log_success "Docker service started successfully"
                else
                    log_error "Failed to start Docker service"
                fi
                ;;
            2)
                echo -e "\nChecking Docker installation:"
                command -v docker >/dev/null && echo "✅ Docker binary found" || echo "❌ Docker binary not found"
                docker --version 2>/dev/null && echo "✅ Docker version accessible" || echo "❌ Docker version not accessible"
                docker info >/dev/null 2>&1 && echo "✅ Docker daemon accessible" || echo "❌ Docker daemon not accessible"
                ;;
            3)
                echo "Exiting..."
                exit 0
                ;;
        esac
        return
    fi
    
    echo -e "\nDocker Management Menu:"
    select option in \
        "Show Containers" \
        "Show Images" \
        "Show Volumes" \
        "Show Networks" \
        "Show Compose Projects" \
        "Show System Information" \
        "Show All" \
        "Show Cache and Data" \
        "Container Management" \
        "Image Management" \
        "Docker Compose Management" \
        "Container Logs Viewer" \
        "Remove All Docker Resources" \
        "Full Docker Cleanup" \
        "View 0xDocker Logs" \
        "Exit"; do

        case $REPLY in
            1) show_containers; break ;;
            2) show_images; break ;;
            3) show_volumes; break ;;
            4) show_networks; break ;;
            5) show_docker_compose_projects; break ;;
            6) show_system_info; break ;;
            7) show_all; break ;;
            8) show_cache_and_data; break ;;
            9) container_management; break ;;
            10) image_management; break ;;
            11) docker_compose_management; break ;;
            12) container_logs_viewer; break ;;
            13) remove_all; break ;;
            14) full_cleanup; break ;;
            15)
                if [ -f "$LOG_FILE" ]; then
                    echo -e "\n=== Recent 0xDocker Logs ==="
                    tail -50 "$LOG_FILE"
                else
                    log_info "No 0xDocker log file found"
                fi
                break ;;
            16) echo "Exiting..."; exit 0 ;;
            *) echo "Invalid option. Try again."; break ;;
        esac
    done
}

# =============================================================================
# DAEMON MODE FUNCTIONS
# =============================================================================
function daemon_mode() {
    log_info "Starting 0xDocker in daemon mode..."
    echo "=== 0xDocker Daemon Started: $(date) ===" >> "$LOG_FILE"
    
    # Run monitoring loop
    while true; do
        # Log Docker status every 5 minutes
        if check_docker_status >/dev/null 2>&1; then
            echo "$(date): Docker is running" >> "$LOG_FILE"
        else
            echo "$(date): Docker is not running" >> "$LOG_FILE"
        fi
        
        # Check for any stopped containers and log them
        local stopped_containers=$(docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | tail -n +2)
        if [ -n "$stopped_containers" ]; then
            echo "$(date): Found stopped containers:" >> "$LOG_FILE"
            echo "$stopped_containers" >> "$LOG_FILE"
        fi
        
        # Sleep for 5 minutes
        sleep 300
    done
}

# =============================================================================
# MAIN EXECUTION LOOP
# =============================================================================

# Handle command line arguments
if [ "$1" = "--daemon" ]; then
    check_docker_installed
    daemon_mode
    exit 0
fi

# Check Docker installation on startup
check_docker_installed

# Initialize log file
echo "=== 0xDocker Management Session Started: $(date) ===" >> "$LOG_FILE"

while true; do
    show_main_menu
    echo -e "\nPress Enter to return to the menu..."
    read
done

__ZEROXDOCKER_SH_END__
