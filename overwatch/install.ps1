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
1. Detect your system architecture
2. Download the latest release from GitHub
3. Install to the specified directory
4. Add the directory to your PATH

"@
    exit 0
}

# Detect architecture
function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    $archReal = $env:PROCESSOR_ARCHITEW6432
    
    if ($archReal -eq "AMD64" -or $arch -eq "AMD64") {
        return "x86_64"
    }
    elseif ($archReal -eq "ARM64" -or $arch -eq "ARM64") {
        return "aarch64"
    }
    else {
        Write-Error-Custom "Unsupported architecture: $arch (real: $archReal)"
    }
}

# Get platform string
function Get-Platform {
    $arch = Get-Architecture
    return "x86_64-pc-windows-msvc"  # Currently only support x64 Windows
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

# Download and extract
function Install-Overwatch {
    $platform = Get-Platform
    Write-Info "Detected platform: $platform"
    
    # For Windows, we expect a .exe file directly or in a zip
    $archiveName = "overwatch-$platform.zip"
    $downloadUrl = "https://github.com/$GitHubRepo/releases/latest/download/$archiveName"
    
    Write-Info "Downloading from: $downloadUrl"
    
    # Create temporary directory
    $tempDir = Join-Path $env:TEMP "overwatch-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    try {
        $archivePath = Join-Path $tempDir $archiveName
        
        # Download the archive
        try {
            Write-Info "Downloading $archiveName..."
            Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing
            Write-Info "Downloaded $archiveName"
        }
        catch {
            # Try direct .exe download as fallback
            $exeName = "overwatch-$platform.exe"
            $exeUrl = "https://github.com/$GitHubRepo/releases/latest/download/$exeName"
            $exePath = Join-Path $tempDir $BinaryName
            
            Write-Info "Trying direct download: $exeUrl"
            try {
                Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing
                Write-Info "Downloaded $exeName"
                
                # Create install directory
                if (-not (Test-Path $InstallDir)) {
                    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
                }
                
                # Copy binary
                $finalPath = Join-Path $InstallDir $BinaryName
                Copy-Item $exePath $finalPath -Force
                
                Write-Success "Installed $BinaryName to $finalPath"
                return
            }
            catch {
                Write-Error-Custom "Failed to download from both $downloadUrl and $exeUrl. Error: $_"
            }
        }
        
        # Extract archive if we got here
        if (Test-Path $archivePath) {
            Write-Info "Extracting archive..."
            
            # Handle different archive types
            if ($archiveName.EndsWith('.zip')) {
                Expand-Archive -Path $archivePath -DestinationPath $tempDir -Force
            }
            else {
                Write-Error-Custom "Unsupported archive format: $archiveName"
            }
            
            # Find the binary
            $binaryPath = ""
            $possiblePaths = @(
                (Join-Path $tempDir $BinaryName),
                (Join-Path $tempDir "bin\$BinaryName"),
                (Join-Path $tempDir "*\$BinaryName")
            )
            
            foreach ($path in $possiblePaths) {
                $found = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                if ($found) {
                    $binaryPath = $found[0].FullName
                    break
                }
            }
            
            if (-not $binaryPath -or -not (Test-Path $binaryPath)) {
                # Search recursively
                $found = Get-ChildItem -Path $tempDir -Name $BinaryName -Recurse -ErrorAction SilentlyContinue
                if ($found) {
                    $binaryPath = Join-Path $tempDir $found[0]
                }
            }
            
            if (-not $binaryPath -or -not (Test-Path $binaryPath)) {
                Write-Error-Custom "Could not find $BinaryName binary in the downloaded archive"
            }
            
            Write-Info "Found binary at: $binaryPath"
            
            # Create install directory
            if (-not (Test-Path $InstallDir)) {
                New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
            }
            
            # Copy binary
            $finalPath = Join-Path $InstallDir $BinaryName
            Copy-Item $binaryPath $finalPath -Force
            
            Write-Success "Installed $BinaryName to $finalPath"
        }
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