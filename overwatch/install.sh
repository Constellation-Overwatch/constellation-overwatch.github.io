#!/bin/bash
set -euo pipefail

# Constellation Overwatch installer script
# Downloads platform-specific binaries from GitHub Releases

# Configuration
GITHUB_REPO="Constellation-Overwatch/constellation-overwatch"
BINARY_NAME="overwatch"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
info() {
    printf "${BLUE}info${NC}: %s\n" "$1"
}

warn() {
    printf "${YELLOW}warning${NC}: %s\n" "$1"
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

    info "Detected platform: ${OS}/${ARCH}"
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

    info "Verifying checksum..."

    # Extract expected hash from checksums file
    expected_hash=$(grep "$filename" "$checksums_file" | awk '{print $1}')

    if [ -z "$expected_hash" ]; then
        warn "Could not find checksum for $filename, skipping verification"
        return 0
    fi

    # Calculate actual hash
    if command_exists sha256sum; then
        actual_hash=$(sha256sum "$file" | awk '{print $1}')
    elif command_exists shasum; then
        actual_hash=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        warn "No checksum tool available, skipping verification"
        return 0
    fi

    if [ "$expected_hash" = "$actual_hash" ]; then
        success "Checksum verified"
        return 0
    fi

    error "Checksum verification failed! Expected: $expected_hash, Got: $actual_hash"
}

# Download and install binary
download_and_install() {
    local version archive_name download_url checksums_url

    version="${1:-$(get_latest_version)}"
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT

    archive_name="${BINARY_NAME}_${version}_${OS}_${ARCH}.${EXT}"
    download_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/${archive_name}"
    checksums_url="https://github.com/${GITHUB_REPO}/releases/download/${version}/${BINARY_NAME}_${version}_checksums.txt"

    info "Downloading ${BINARY_NAME} ${version} for ${OS}/${ARCH}..."

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
    info "Extracting..."
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

    # Create install directory
    mkdir -p "$INSTALL_DIR" || error "Failed to create install directory: $INSTALL_DIR"

    # Install the binary
    if [ -w "$INSTALL_DIR" ]; then
        install -m 755 "$BINARY_NAME" "$INSTALL_DIR/"
    else
        info "Elevated permissions required for $INSTALL_DIR"
        sudo install -m 755 "$BINARY_NAME" "$INSTALL_DIR/"
    fi

    success "Installed $BINARY_NAME to $INSTALL_DIR/$BINARY_NAME"
}

# Update PATH if needed
update_path() {
    local shell_rc

    # Check if install directory is already in PATH
    if echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
        info "$INSTALL_DIR is already in PATH"
        return 0
    fi

    # Determine shell configuration file
    case "${SHELL:-}" in
        */zsh)  shell_rc="$HOME/.zshrc" ;;
        */bash)
            if [ -f "$HOME/.bashrc" ]; then
                shell_rc="$HOME/.bashrc"
            else
                shell_rc="$HOME/.bash_profile"
            fi
            ;;
        */fish) shell_rc="$HOME/.config/fish/config.fish" ;;
        *)
            if [ -f "$HOME/.profile" ]; then
                shell_rc="$HOME/.profile"
            else
                warn "Could not determine shell configuration file"
                warn "Please add $INSTALL_DIR to your PATH manually"
                return 1
            fi
            ;;
    esac

    # Add to PATH if not already present
    if [ -f "$shell_rc" ] && grep -q "$INSTALL_DIR" "$shell_rc" 2>/dev/null; then
        info "PATH already configured in $shell_rc"
    else
        info "Updating PATH in $shell_rc"
        {
            echo ""
            echo "# Added by Constellation Overwatch installer"
            echo "export PATH=\"$INSTALL_DIR:\$PATH\""
        } >> "$shell_rc"
        success "Added $INSTALL_DIR to PATH in $shell_rc"

        info "Please restart your shell or run:"
        printf "  ${CYAN}source %s${NC}\n" "$shell_rc"
    fi
}

# Verify installation
verify_installation() {
    if [ -x "$INSTALL_DIR/$BINARY_NAME" ]; then
        local version
        version=$("$INSTALL_DIR/$BINARY_NAME" -version 2>/dev/null || echo "unknown")
        success "$BINARY_NAME installed successfully!"
        info "Version: $version"
        info "Location: $INSTALL_DIR/$BINARY_NAME"

        # Test if it's in PATH
        if command_exists "$BINARY_NAME"; then
            info "You can now run: ${CYAN}$BINARY_NAME --help${NC}"
        else
            warn "Binary not in PATH. You may need to restart your shell."
            info "Or run: ${CYAN}$INSTALL_DIR/$BINARY_NAME --help${NC}"
        fi
    else
        error "Installation verification failed"
    fi
}

# Print usage
usage() {
    cat <<EOF
Constellation Overwatch Installer

USAGE:
    install.sh [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -v, --version VER   Install a specific version (e.g., v0.0.5-beta)
    -d, --dir DIR       Install to a specific directory (default: ~/.local/bin)

ENVIRONMENT VARIABLES:
    INSTALL_DIR         Override default installation directory

EXAMPLES:
    # Install latest version
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash

    # Install specific version
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash -s -- -v v0.0.5-beta

    # Install to custom directory
    INSTALL_DIR=/opt/bin curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash
EOF
}

# Main installation process
main() {
    local version=""

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
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done

    echo
    printf "${CYAN}Constellation Overwatch Installer${NC}\n"
    echo

    # Detect platform
    detect_platform

    # Install
    download_and_install "$version"
    update_path
    verify_installation

    echo
    printf "${GREEN}Installation complete!${NC}\n"
    echo
    printf "Next steps:\n"
    printf "  1. Restart your shell or run: ${CYAN}source ~/.zshrc${NC} (or your shell's config)\n"
    printf "  2. Start the server: ${CYAN}overwatch${NC}\n"
    printf "  3. Visit: ${CYAN}http://localhost:8080${NC}\n"
    echo
    printf "Documentation: ${BLUE}https://constellation-overwatch.github.io${NC}\n"
    printf "GitHub: ${BLUE}https://github.com/${GITHUB_REPO}${NC}\n"
}

main "$@"
