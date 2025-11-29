# Constellation Overwatch PowerShell installer script
# Downloads platform-specific binaries from GitHub Releases

param(
    [string]$InstallDir = "$env:USERPROFILE\AppData\Local\overwatch",
    [string]$Version = "",
    [switch]$Help
)

# Configuration
$GitHubRepo = "Constellation-Overwatch/constellation-overwatch"
$BinaryName = "overwatch"
$ProgressPreference = 'SilentlyContinue'  # Disable progress bar for faster downloads

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "info: $Message" -Color "Blue"
}

function Write-Warn {
    param([string]$Message)
    Write-ColorOutput "warning: $Message" -Color "Yellow"
}

function Write-ErrorCustom {
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
    -InstallDir <path>    Custom installation directory (default: %USERPROFILE%\AppData\Local\overwatch)
    -Version <version>    Install a specific version (e.g., v0.0.5-beta)
    -Help                 Show this help message

EXAMPLES:
    # Install latest version
    irm https://raw.githubusercontent.com/Constellation-Overwatch/constellation-overwatch/main/install.ps1 | iex

    # Install to custom directory
    .\install.ps1 -InstallDir "C:\tools\overwatch"

    # Install specific version
    .\install.ps1 -Version "v0.0.5-beta"

The installer will:
1. Detect your system architecture (amd64/arm64)
2. Download the appropriate release from GitHub
3. Verify the checksum
4. Install to the specified directory
5. Add the directory to your PATH

"@
    exit 0
}

# Detect architecture
function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "amd64" }
        "ARM64" { return "arm64" }
        "x86"   {
            # Check if running on 64-bit OS
            if ([Environment]::Is64BitOperatingSystem) {
                return "amd64"
            }
            Write-ErrorCustom "32-bit systems are not supported"
        }
        default { Write-ErrorCustom "Unsupported architecture: $arch" }
    }
}

# Get latest version from GitHub API
function Get-LatestVersion {
    $apiUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        return $response.tag_name
    }
    catch {
        Write-ErrorCustom "Failed to fetch latest version from GitHub: $_"
    }
}

# Verify checksum
function Test-Checksum {
    param(
        [string]$FilePath,
        [string]$ChecksumsContent,
        [string]$FileName
    )

    Write-Info "Verifying checksum..."

    # Parse checksums file to find the expected hash
    $lines = $ChecksumsContent -split "`n"
    $expectedHash = $null

    foreach ($line in $lines) {
        if ($line -match "^([a-fA-F0-9]{64})\s+$([regex]::Escape($FileName))") {
            $expectedHash = $matches[1]
            break
        }
    }

    if (-not $expectedHash) {
        Write-Warn "Could not find checksum for $FileName, skipping verification"
        return $true
    }

    # Calculate actual hash
    $actualHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash

    if ($actualHash -ieq $expectedHash) {
        Write-Success "Checksum verified"
        return $true
    }
    else {
        Write-ErrorCustom "Checksum mismatch! Expected: $expectedHash, Got: $actualHash"
        return $false
    }
}

# Check if directory is in PATH
function Test-PathDirectory {
    param([string]$Directory)

    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if (-not $currentPath) { return $false }

    $normalizedDir = $Directory.TrimEnd('\').ToLower()
    return ($currentPath -split ";" | ForEach-Object { $_.TrimEnd('\').ToLower() }) -contains $normalizedDir
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
        Write-ErrorCustom "Failed to update PATH: $_"
    }
}

# Download and install
function Install-Overwatch {
    param([string]$TargetVersion)

    $arch = Get-Architecture
    Write-Info "Detected architecture: $arch"

    # Get version
    if (-not $TargetVersion) {
        $TargetVersion = Get-LatestVersion
    }
    Write-Info "Installing version: $TargetVersion"

    # Build download URLs
    $archiveName = "${BinaryName}_${TargetVersion}_windows_${arch}.zip"
    $downloadUrl = "https://github.com/$GitHubRepo/releases/download/$TargetVersion/$archiveName"
    $checksumsUrl = "https://github.com/$GitHubRepo/releases/download/$TargetVersion/${BinaryName}_${TargetVersion}_checksums.txt"

    Write-Info "Downloading $archiveName..."

    # Create temporary directory
    $tempDir = Join-Path $env:TEMP "overwatch-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        $tempArchivePath = Join-Path $tempDir $archiveName
        $tempExtractPath = Join-Path $tempDir "extract"

        # Download the archive
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempArchivePath -UseBasicParsing
        }
        catch {
            Write-ErrorCustom "Failed to download from $downloadUrl. Error: $_"
        }

        # Download and verify checksum
        try {
            $checksumsContent = Invoke-WebRequest -Uri $checksumsUrl -UseBasicParsing | Select-Object -ExpandProperty Content
            Test-Checksum -FilePath $tempArchivePath -ChecksumsContent $checksumsContent -FileName $archiveName
        }
        catch {
            Write-Warn "Could not download checksums file, skipping verification"
        }

        # Extract archive
        Write-Info "Extracting..."
        New-Item -ItemType Directory -Path $tempExtractPath -Force | Out-Null
        Expand-Archive -Path $tempArchivePath -DestinationPath $tempExtractPath -Force

        # Create install directory
        if (-not (Test-Path $InstallDir)) {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        }

        # Find and copy binary
        $sourceBinary = Get-ChildItem -Path $tempExtractPath -Filter "$BinaryName.exe" -Recurse | Select-Object -First 1
        if (-not $sourceBinary) {
            Write-ErrorCustom "Binary not found in archive"
        }

        $finalPath = Join-Path $InstallDir "$BinaryName.exe"
        Copy-Item $sourceBinary.FullName $finalPath -Force

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
    $binaryPath = Join-Path $InstallDir "$BinaryName.exe"

    if (Test-Path $binaryPath) {
        Write-Success "$BinaryName installed successfully!"
        Write-Info "Location: $binaryPath"

        # Try to get version
        try {
            $versionOutput = & $binaryPath -version 2>&1
            if ($versionOutput) {
                Write-Info "Version: $versionOutput"
            }
        }
        catch {
            Write-Info "Version: unknown"
        }

        # Test if it's in PATH
        try {
            $testResult = Get-Command $BinaryName -ErrorAction SilentlyContinue
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
        Write-ErrorCustom "Installation verification failed"
    }
}

# Main installation process
function Main {
    Write-Host ""
    Write-ColorOutput "Constellation Overwatch Installer" -Color "Cyan"
    Write-Host ""

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-ErrorCustom "PowerShell 5.0 or later is required"
    }

    try {
        Install-Overwatch -TargetVersion $Version
        Add-ToPath -Directory $InstallDir
        Test-Installation

        Write-Host ""
        Write-ColorOutput "Installation complete!" -Color "Green"
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
        Write-ErrorCustom "Installation failed: $_"
    }
}

# Run main function
Main
