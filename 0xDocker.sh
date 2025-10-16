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
if [[ "$0" != "$TARGET" ]]; then
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
