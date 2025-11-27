# Constellation Overwatch PowerShell installer script
# Based on uv's installer pattern for Windows

param(
    [string]$InstallDir = "$env:USERPROFILE\AppData\Local\overwatch",
    [switch]$Help
)

# Configuration
$GitHubRepo = "Constellation-Overwatch/constellation-overwatch"
$BinaryName = "overwatch.exe"
$ProgressPreference = 'SilentlyContinue'  # Disable progress bar for faster downloads

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green"
        "Yellow" = "Yellow"
        "Blue" = "Blue"
        "Cyan" = "Cyan"
        "White" = "White"
    }
    
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "info: $Message" -Color "Blue"
}

function Write-Warn {
    param([string]$Message)
    Write-ColorOutput "warning: $Message" -Color "Yellow"
}

function Write-Error-Custom {
    param([string]$Message)
    Write-ColorOutput "error: $Message" -Color "Red"
    exit 1
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "success: $Message" -Color "Green"
}

# Show help
if ($Help) {
    @"
Constellation Overwatch Installer

USAGE:
    install.ps1 [OPTIONS]

OPTIONS:
    -InstallDir <path>    Custom installation directory (default: $env:USERPROFILE\AppData\Local\overwatch)
    -Help                 Show this help message

EXAMPLES:
    # Install to default location
    install.ps1
    
    # Install to custom directory
    install.ps1 -InstallDir "C:\tools\overwatch"

The installer will:
1. Download the latest release from GitHub
2. Install to the specified directory
3. Add the directory to your PATH

"@
    exit 0
}

# Download binary from GitHub releases
function Get-OverwatchBinary {
    return $BinaryName
}

# Check if directory is in PATH
function Test-PathDirectory {
    param([string]$Directory)
    
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    return $currentPath -split ";" | ForEach-Object { $_.TrimEnd('\') } | Where-Object { $_ -eq $Directory.TrimEnd('\') }
}

# Add directory to PATH
function Add-ToPath {
    param([string]$Directory)
    
    if (Test-PathDirectory -Directory $Directory) {
        Write-Info "$Directory is already in PATH"
        return
    }
    
    Write-Info "Adding $Directory to user PATH"
    
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath) {
        $newPath = "$currentPath;$Directory"
    }
    else {
        $newPath = $Directory
    }
    
    try {
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        
        # Update current session PATH
        $env:PATH = "$env:PATH;$Directory"
        
        Write-Success "Added $Directory to PATH"
        Write-Info "You may need to restart your terminal for PATH changes to take effect"
    }
    catch {
        Write-Error-Custom "Failed to update PATH: $_"
    }
}

# Download and install
function Install-Overwatch {
    $downloadUrl = "https://github.com/$GitHubRepo/releases/latest/download/$BinaryName"
    
    Write-Info "Downloading binary from GitHub releases..."
    Write-Info "Download URL: $downloadUrl"
    
    # Create temporary directory
    $tempDir = Join-Path $env:TEMP "overwatch-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    try {
        $tempBinaryPath = Join-Path $tempDir $BinaryName
        
        # Download the binary directly
        try {
            Write-Info "Downloading $BinaryName..."
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempBinaryPath -UseBasicParsing
            Write-Info "Downloaded $BinaryName successfully"
        }
        catch {
            Write-Error-Custom "Failed to download from $downloadUrl. Error: $_"
        }
        
        # Verify the download
        if (-not (Test-Path $tempBinaryPath)) {
            Write-Error-Custom "Downloaded file not found at $tempBinaryPath"
        }
        
        # Create install directory
        if (-not (Test-Path $InstallDir)) {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        }
        
        # Copy binary to install directory
        $finalPath = Join-Path $InstallDir $BinaryName
        Copy-Item $tempBinaryPath $finalPath -Force
        
        Write-Success "Installed $BinaryName to $finalPath"
    }
    finally {
        # Clean up temp directory
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Verify installation
function Test-Installation {
    $binaryPath = Join-Path $InstallDir $BinaryName
    
    if (Test-Path $binaryPath) {
        Write-Success "$BinaryName installed successfully!"
        Write-Info "Location: $binaryPath"
        
        # Try to get version
        try {
            $version = & $binaryPath --version 2>$null
            if ($version) {
                Write-Info "Version: $version"
            }
        }
        catch {
            Write-Info "Version: unknown"
        }
        
        # Test if it's in PATH
        try {
            $testResult = Get-Command $BinaryName.Replace('.exe', '') -ErrorAction SilentlyContinue
            if ($testResult) {
                Write-Info "You can now run: overwatch --help"
            }
            else {
                Write-Warn "Binary not in PATH. You may need to restart your terminal."
                Write-Info "Or run: $binaryPath --help"
            }
        }
        catch {
            Write-Info "Run: $binaryPath --help"
        }
    }
    else {
        Write-Error-Custom "Installation verification failed"
    }
}

# Main installation process
function Main {
    Write-Info "Installing Constellation Overwatch..."
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error-Custom "PowerShell 5.0 or later is required"
    }
    
    try {
        Install-Overwatch
        Add-ToPath -Directory $InstallDir
        Test-Installation
        
        Write-Host ""
        Write-ColorOutput "🚀 Constellation Overwatch installation complete!" -Color "Green"
        Write-Host ""
        Write-Host "Next steps:"
        Write-ColorOutput "  1. Restart your terminal (or open a new one)" -Color "Cyan"
        Write-ColorOutput "  2. Start the server: overwatch" -Color "Cyan"
        Write-ColorOutput "  3. Visit: http://localhost:8080" -Color "Cyan"
        Write-Host ""
        Write-ColorOutput "Documentation: https://constellation-overwatch.github.io" -Color "Blue"
        Write-ColorOutput "GitHub: https://github.com/$GitHubRepo" -Color "Blue"
    }
    catch {
        Write-Error-Custom "Installation failed: $_"
    }
}

# Run main function
Main