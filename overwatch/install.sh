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

# Download binary from GitHub releases
download_binary() {
    local temp_dir download_url
    
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    
    download_url="https://github.com/${GITHUB_REPO}/releases/latest/download/${BINARY_NAME}"
    
    info "Downloading binary from GitHub releases..."
    
    if command_exists curl; then
        curl -fsSL "$download_url" -o "$temp_dir/$BINARY_NAME" || error "Failed to download binary"
    elif command_exists wget; then
        wget -q "$download_url" -O "$temp_dir/$BINARY_NAME" || error "Failed to download binary"
    else
        error "Either curl or wget is required for installation"
    fi
    
    # Create install directory
    mkdir -p "$INSTALL_DIR" || error "Failed to create install directory: $INSTALL_DIR"
    
    # Install the binary
    cp "$temp_dir/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME" || error "Failed to copy binary to $INSTALL_DIR"
    chmod +x "$INSTALL_DIR/$BINARY_NAME" || error "Failed to make binary executable"
    
    success "Downloaded and installed $BINARY_NAME to $INSTALL_DIR/$BINARY_NAME"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install overwatch binary
install_overwatch() {
    download_binary
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