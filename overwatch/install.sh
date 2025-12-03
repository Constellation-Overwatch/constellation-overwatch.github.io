#!/bin/bash
set -euo pipefail

# Constellation Overwatch installer script
# Downloads platform-specific binaries from GitHub Releases
# Installs to ~/.overwatch/ with proper env script setup (UV-style)

# Configuration
GITHUB_REPO="Constellation-Overwatch/constellation-overwatch"
BINARY_NAME="overwatch"
APP_VERSION=""  # Will be set during install

# Installation paths - everything under ~/.overwatch for simplicity
# Works identically on Linux/macOS/WSL
OVERWATCH_HOME="${OVERWATCH_HOME:-$HOME/.overwatch}"
INSTALL_DIR="${OVERWATCH_INSTALL_DIR:-$OVERWATCH_HOME/bin}"
DATA_DIR="$OVERWATCH_HOME/data"

# Control flags
NO_MODIFY_PATH="${OVERWATCH_NO_MODIFY_PATH:-0}"
PRINT_VERBOSE="${OVERWATCH_VERBOSE:-0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
say() {
    printf "%s\n" "$1"
}

say_verbose() {
    if [ "$PRINT_VERBOSE" = "1" ]; then
        printf "%s\n" "$1"
    fi
}

info() {
    printf "${BLUE}info${NC}: %s\n" "$1"
}

warn() {
    printf "${YELLOW}warn${NC}: %s\n" "$1"
}

error() {
    printf "${RED}error${NC}: %s\n" "$1" >&2
    exit 1
}

success() {
    printf "${GREEN}success${NC}: %s\n" "$1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect platform (OS and architecture)
detect_platform() {
    local os arch

    # Detect OS
    case "$(uname -s)" in
        Linux*)  os="linux" ;;
        Darwin*) os="darwin" ;;
        CYGWIN*|MINGW*|MSYS*) os="windows" ;;
        *)       error "Unsupported operating system: $(uname -s)" ;;
    esac

    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)  arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)             error "Unsupported architecture: $(uname -m)" ;;
    esac

    # Set archive extension based on OS
    if [ "$os" = "windows" ]; then
        EXT="zip"
    else
        EXT="tar.gz"
    fi

    OS="$os"
    ARCH="$arch"

    say_verbose "Detected platform: ${OS}/${ARCH}"
}

# Get latest version from GitHub API
get_latest_version() {
    local version api_url

    api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

    if command_exists curl; then
        version=$(curl -fsSL "$api_url" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command_exists wget; then
        version=$(wget -qO- "$api_url" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        error "Either curl or wget is required for installation"
    fi

    if [ -z "$version" ]; then
        error "Failed to fetch latest version from GitHub"
    fi

    echo "$version"
}

# Verify checksum of downloaded file
verify_checksum() {
    local file="$1"
    local checksums_file="$2"
    local filename expected_hash actual_hash

    filename=$(basename "$file")

    say_verbose "Verifying checksum..."

    # Extract expected hash from checksums file
    expected_hash=$(grep "$filename" "$checksums_file" | awk '{print $1}')

    if [ -z "$expected_hash" ]; then
        say_verbose "Could not find checksum for $filename, skipping verification"
        return 0
    fi

    # Calculate actual hash
    if command_exists sha256sum; then
        actual_hash=$(sha256sum "$file" | awk '{print $1}')
    elif command_exists shasum; then
        actual_hash=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        say_verbose "No checksum tool available, skipping verification"
        return 0
    fi

    if [ "$expected_hash" = "$actual_hash" ]; then
        say_verbose "Checksum verified"
        return 0
    fi

    error "Checksum verification failed! Expected: $expected_hash, Got: $actual_hash"
}

# Write the sh/bash/zsh env script
write_env_script_sh() {
    local install_dir_expr="$1"
    local env_script_path="$2"

    cat <<EOF > "$env_script_path"
#!/bin/sh
# Constellation Overwatch environment setup
# Add overwatch to PATH if not already present

case ":\${PATH}:" in
    *:"$install_dir_expr":*)
        ;;
    *)
        export PATH="$install_dir_expr:\$PATH"
        ;;
esac

# Optional: Set OVERWATCH_HOME for config discovery
export OVERWATCH_HOME="$OVERWATCH_HOME"
EOF
    chmod +x "$env_script_path"
}

# Write the fish env script
write_env_script_fish() {
    local install_dir_expr="$1"
    local env_script_path="$2"

    cat <<EOF > "$env_script_path"
# Constellation Overwatch environment setup
# Add overwatch to PATH if not already present

if not contains "$install_dir_expr" \$PATH
    set -gx PATH "$install_dir_expr" \$PATH
end

# Optional: Set OVERWATCH_HOME for config discovery
set -gx OVERWATCH_HOME "$OVERWATCH_HOME"
EOF
}

# Write install receipt for upgrade tracking
write_receipt() {
    local version="$1"
    local receipt_path="$OVERWATCH_HOME/receipt.json"

    cat <<EOF > "$receipt_path"
{
  "version": "$version",
  "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "platform": "${OS}/${ARCH}"
}
EOF
    say_verbose "Install receipt written to $receipt_path"
}

# Create ready-to-use .env config
create_default_env() {
    local env_file="$OVERWATCH_HOME/.env"

    # Don't overwrite existing config
    if [ -f "$env_file" ]; then
        say_verbose "Config already exists at $env_file"
        return 0
    fi

    cat <<EOF > "$env_file"
# Constellation Overwatch Configuration
# Data: $DATA_DIR/

API_BEARER_TOKEN=reindustrialize-dev-token
NATS_ENABLE_AUTH=true
NATS_AUTH_TOKEN=reindustrialize-america

DB_PATH=$DATA_DIR/db/constellation.db
NATS_DATA_DIR=$DATA_DIR/nats
EOF

    say_verbose "Created config at $env_file"
}

# Download and install binary
download_and_install() {
    local version archive_name download_url checksums_url

    version="${1:-$(get_latest_version)}"
    APP_VERSION="$version"

    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT

    archive_name="${BINARY_NAME}_${version}_${OS}_${ARCH}.${EXT}"
    download_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/${archive_name}"
    checksums_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/${BINARY_NAME}_${version}_checksums.txt"

    say "Downloading ${BINARY_NAME} ${version} ${OS}/${ARCH}"

    # Download archive
    if command_exists curl; then
        curl -fsSL "$download_url" -o "$TEMP_DIR/$archive_name" || error "Failed to download $archive_name"
    elif command_exists wget; then
        wget -q "$download_url" -O "$TEMP_DIR/$archive_name" || error "Failed to download $archive_name"
    fi

    # Download and verify checksums
    if command_exists curl; then
        curl -fsSL "$checksums_url" -o "$TEMP_DIR/checksums.txt" 2>/dev/null && \
            verify_checksum "$TEMP_DIR/$archive_name" "$TEMP_DIR/checksums.txt"
    elif command_exists wget; then
        wget -q "$checksums_url" -O "$TEMP_DIR/checksums.txt" 2>/dev/null && \
            verify_checksum "$TEMP_DIR/$archive_name" "$TEMP_DIR/checksums.txt"
    fi

    # Extract archive
    say_verbose "Extracting..."
    cd "$TEMP_DIR"

    if [ "$EXT" = "zip" ]; then
        if command_exists unzip; then
            unzip -q "$archive_name"
        else
            error "unzip is required to extract the archive"
        fi
    else
        tar -xzf "$archive_name"
    fi

    # Create install directories (DATA_DIR is under OVERWATCH_HOME)
    mkdir -p "$INSTALL_DIR" || error "Failed to create install directory: $INSTALL_DIR"
    mkdir -p "$DATA_DIR" || error "Failed to create data directory: $DATA_DIR"

    # Install the binary
    if [ -w "$INSTALL_DIR" ]; then
        install -m 755 "$BINARY_NAME" "$INSTALL_DIR/"
    else
        info "Elevated permissions required for $INSTALL_DIR"
        sudo install -m 755 "$BINARY_NAME" "$INSTALL_DIR/"
    fi

    say "Installing to $INSTALL_DIR"
    say "  $BINARY_NAME"
}

# Setup PATH via env scripts (UV-style)
setup_env_scripts() {
    local env_script_path="$OVERWATCH_HOME/env"
    local fish_env_script_path="$OVERWATCH_HOME/env.fish"
    local install_dir_expr="\$HOME/.overwatch/bin"
    local path_updated=0

    # Use literal path if custom install location
    if [ "$OVERWATCH_HOME" != "$HOME/.overwatch" ]; then
        install_dir_expr="$INSTALL_DIR"
    fi

    # Write env scripts
    write_env_script_sh "$install_dir_expr" "$env_script_path"
    write_env_script_fish "$install_dir_expr" "$fish_env_script_path"

    say_verbose "Created $env_script_path"
    say_verbose "Created $fish_env_script_path"

    if [ "$NO_MODIFY_PATH" = "1" ]; then
        return 0
    fi

    # Add to shell rc files
    local source_line=". \"\$HOME/.overwatch/env\""
    local source_line_fish="source \"\$HOME/.overwatch/env.fish\""

    # Use literal paths if custom location
    if [ "$OVERWATCH_HOME" != "$HOME/.overwatch" ]; then
        source_line=". \"$env_script_path\""
        source_line_fish="source \"$fish_env_script_path\""
    fi

    # Update .profile (covers most POSIX shells)
    if [ -f "$HOME/.profile" ]; then
        if ! grep -qF ".overwatch/env" "$HOME/.profile" 2>/dev/null; then
            echo "" >> "$HOME/.profile"
            echo "$source_line" >> "$HOME/.profile"
            path_updated=1
        fi
    fi

    # Update .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -qF ".overwatch/env" "$HOME/.bashrc" 2>/dev/null; then
            echo "" >> "$HOME/.bashrc"
            echo "$source_line" >> "$HOME/.bashrc"
            path_updated=1
        fi
    fi

    # Update .zshrc if it exists (or create if zsh is default shell)
    local zshrc="$HOME/.zshrc"
    if [ -f "$zshrc" ] || [ "${SHELL:-}" = "$(command -v zsh 2>/dev/null)" ]; then
        if ! grep -qF ".overwatch/env" "$zshrc" 2>/dev/null; then
            echo "" >> "$zshrc"
            echo "$source_line" >> "$zshrc"
            path_updated=1
        fi
    fi

    # Update fish config if it exists
    local fish_config="$HOME/.config/fish/conf.d"
    if [ -d "$HOME/.config/fish" ]; then
        mkdir -p "$fish_config"
        local fish_env_link="$fish_config/overwatch.fish"
        if [ ! -f "$fish_env_link" ]; then
            echo "$source_line_fish" > "$fish_env_link"
            path_updated=1
        fi
    fi

    if [ "$path_updated" = "1" ]; then
        return 1  # Signal that shell restart is needed
    fi
    return 0
}

# Print usage
usage() {
    cat <<EOF
${BOLD}Constellation Overwatch Installer${NC}

${BOLD}USAGE:${NC}
    install.sh [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help              Show this help message
    -v, --version VER       Install a specific version (e.g., v0.0.5-beta)
    -q, --quiet             Suppress non-essential output
    --verbose               Enable verbose output
    --no-modify-path        Don't modify PATH in shell configs

${BOLD}ENVIRONMENT VARIABLES:${NC}
    OVERWATCH_HOME          Override overwatch home (default: ~/.overwatch)
    OVERWATCH_INSTALL_DIR   Override binary install location (default: ~/.overwatch/bin)
    OVERWATCH_NO_MODIFY_PATH  Set to 1 to skip PATH configuration
    OVERWATCH_VERBOSE       Set to 1 for verbose output

${BOLD}EXAMPLES:${NC}
    # Install latest version
    curl -fsSL https://constellation-overwatch.github.io/overwatch/install.sh | bash

    # Install specific version
    curl -fsSL https://constellation-overwatch.github.io/overwatch/install.sh | bash -s -- -v v0.0.5-beta

    # Install without modifying PATH
    OVERWATCH_NO_MODIFY_PATH=1 curl -fsSL https://constellation-overwatch.github.io/overwatch/install.sh | bash

${BOLD}INSTALL LOCATIONS:${NC}
    ~/.overwatch/
    ├── bin/overwatch     Binary
    ├── data/             Database + NATS storage
    ├── env               PATH script (sh/bash/zsh)
    ├── env.fish          PATH script (fish)
    ├── .env              Configuration
    └── receipt.json      Install metadata
EOF
}

# Main installation process
main() {
    local version=""
    local needs_shell_restart=0

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                version="$2"
                shift 2
                ;;
            -q|--quiet)
                PRINT_VERBOSE=0
                shift
                ;;
            --verbose)
                PRINT_VERBOSE=1
                shift
                ;;
            --no-modify-path)
                NO_MODIFY_PATH=1
                shift
                ;;
            *)
                error "Unknown option: $1. Use --help for usage."
                ;;
        esac
    done

    echo ""
    printf "${CYAN}${BOLD}Constellation Overwatch${NC}\n"
    echo ""

    # Detect platform
    detect_platform

    # Install
    download_and_install "$version"

    # Setup env scripts and PATH
    if ! setup_env_scripts; then
        needs_shell_restart=1
    fi

    # Write install receipt
    write_receipt "$APP_VERSION"

    # Create example config
    create_default_env

    # Final output
    echo ""
    printf "${GREEN}${BOLD}Overwatch installed!${NC}\n"
    echo ""

    # Show single command to get started (no restart needed)
    if [ "$needs_shell_restart" = "1" ]; then
        say "To start now, run:"
        echo ""
        printf "    ${CYAN}source ~/.overwatch/env && overwatch${NC}\n"
    else
        say "To start, run:"
        echo ""
        printf "    ${CYAN}overwatch${NC}\n"
    fi
    echo ""
    say "Then visit ${CYAN}http://localhost:8080${NC}"
    echo ""
}

main "$@"
