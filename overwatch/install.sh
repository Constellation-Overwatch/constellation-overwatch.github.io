#!/bin/bash
set -e

# Constellation Overwatch installer script
# Based on uv's installer pattern

# Configuration
GITHUB_REPO="Constellation-Overwatch/constellation-overwatch"
BINARY_NAME="overwatch"
INSTALL_DIR="$HOME/.local/bin"

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

# Detect OS and architecture
detect_platform() {
    local os arch
    
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux) os="linux" ;;
        *) error "Unsupported OS: $(uname -s)" ;;
    esac
    
    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) error "Unsupported architecture: $(uname -m)" ;;
    esac
    
    if [ "$os" = "darwin" ] && [ "$arch" = "x86_64" ]; then
        echo "x86_64-apple-darwin"
    elif [ "$os" = "darwin" ] && [ "$arch" = "aarch64" ]; then
        echo "aarch64-apple-darwin"
    elif [ "$os" = "linux" ] && [ "$arch" = "x86_64" ]; then
        echo "x86_64-unknown-linux-gnu"
    elif [ "$os" = "linux" ] && [ "$arch" = "aarch64" ]; then
        echo "aarch64-unknown-linux-gnu"
    else
        error "Unsupported platform: $os-$arch"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Download and install
install_overwatch() {
    local platform download_url temp_dir archive_name
    
    platform=$(detect_platform)
    info "Detected platform: $platform"
    
    # Determine archive extension based on platform
    if [[ "$platform" == *"darwin"* ]]; then
        archive_name="${BINARY_NAME}-${platform}.tar.gz"
    else
        archive_name="${BINARY_NAME}-${platform}.tar.gz"
    fi
    
    download_url="https://github.com/${GITHUB_REPO}/releases/latest/download/${archive_name}"
    
    info "Downloading from: $download_url"
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    
    # Download the archive
    if command_exists curl; then
        curl -fsSL -o "$temp_dir/$archive_name" "$download_url" || error "Failed to download $archive_name"
    elif command_exists wget; then
        wget -q -O "$temp_dir/$archive_name" "$download_url" || error "Failed to download $archive_name"
    else
        error "Neither curl nor wget found. Please install one of them."
    fi
    
    info "Downloaded $archive_name"
    
    # Extract the archive
    cd "$temp_dir"
    if [[ "$archive_name" == *.tar.gz ]]; then
        tar -xzf "$archive_name" || error "Failed to extract $archive_name"
    else
        error "Unsupported archive format: $archive_name"
    fi
    
    # Find the binary (it might be in a subdirectory)
    binary_path=""
    if [ -f "$BINARY_NAME" ]; then
        binary_path="$BINARY_NAME"
    elif [ -f "bin/$BINARY_NAME" ]; then
        binary_path="bin/$BINARY_NAME"
    elif [ -f "./$BINARY_NAME" ]; then
        binary_path="./$BINARY_NAME"
    else
        # Try to find it recursively
        binary_path=$(find . -name "$BINARY_NAME" -type f | head -n1)
        if [ -z "$binary_path" ]; then
            error "Could not find $BINARY_NAME binary in the downloaded archive"
        fi
    fi
    
    info "Found binary at: $binary_path"
    
    # Create install directory
    mkdir -p "$INSTALL_DIR" || error "Failed to create install directory: $INSTALL_DIR"
    
    # Install the binary
    cp "$binary_path" "$INSTALL_DIR/$BINARY_NAME" || error "Failed to copy binary to $INSTALL_DIR"
    chmod +x "$INSTALL_DIR/$BINARY_NAME" || error "Failed to make binary executable"
    
    success "Installed $BINARY_NAME to $INSTALL_DIR/$BINARY_NAME"
}

# Update PATH if needed
update_path() {
    local shell_rc
    
    # Check if install directory is already in PATH
    if echo "$PATH" | grep -q "$INSTALL_DIR"; then
        info "$INSTALL_DIR is already in PATH"
        return 0
    fi
    
    # Determine shell configuration file
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            shell_rc="$HOME/.bashrc"
        else
            shell_rc="$HOME/.bash_profile"
        fi
    elif [ -f "$HOME/.profile" ]; then
        shell_rc="$HOME/.profile"
    else
        warn "Could not determine shell configuration file"
        warn "Please add $INSTALL_DIR to your PATH manually"
        return 1
    fi
    
    info "Updating PATH in $shell_rc"
    
    # Add to PATH if not already present
    if [ -f "$shell_rc" ] && grep -q "$INSTALL_DIR" "$shell_rc"; then
        info "PATH already configured in $shell_rc"
    else
        echo "" >> "$shell_rc"
        echo "# Added by Constellation Overwatch installer" >> "$shell_rc"
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$shell_rc"
        success "Added $INSTALL_DIR to PATH in $shell_rc"
        
        info "Please restart your shell or run:"
        printf "  ${CYAN}source %s${NC}\n" "$shell_rc"
    fi
}

# Verify installation
verify_installation() {
    if [ -x "$INSTALL_DIR/$BINARY_NAME" ]; then
        local version
        version=$("$INSTALL_DIR/$BINARY_NAME" --version 2>/dev/null || echo "unknown")
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

# Main installation process
main() {
    info "Installing Constellation Overwatch..."
    
    # Check for required tools
    if ! command_exists curl && ! command_exists wget; then
        error "Either curl or wget is required for installation"
    fi
    
    if ! command_exists tar; then
        error "tar is required for installation"
    fi
    
    # Install
    install_overwatch
    update_path
    verify_installation
    
    echo
    printf "${GREEN}🚀 Constellation Overwatch installation complete!${NC}\n"
    echo
    printf "Next steps:\n"
    printf "  1. Restart your shell or run: ${CYAN}source ~/.zshrc${NC} (or your shell's config)\n"
    printf "  2. Start the server: ${CYAN}overwatch${NC}\n"
    printf "  3. Visit: ${CYAN}http://localhost:8080${NC}\n"
    echo
    printf "Documentation: ${BLUE}https://constellation-overwatch.github.io${NC}\n"
    printf "GitHub: ${BLUE}https://github.com/${GITHUB_REPO}${NC}\n"
}

# Allow running specific functions (for testing)
if [ $# -gt 0 ]; then
    "$@"
else
    main
fi