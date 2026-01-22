#!/bin/bash

# =============================================================================
# MDK SDK Download Script
# =============================================================================
# This script downloads all mdk-sdk packages from SourceForge nightly builds
# for all supported platforms and architectures.
#
# Usage:
#   ./download_mdk_sdk.sh [output_directory]
#
# Example:
#   ./download_mdk_sdk.sh ./mdk-packages
# =============================================================================

set -e

# Configuration
SOURCEFORGE_BASE_URL="https://sourceforge.net/projects/mdk-sdk/files/nightly"
BUNDLE_VERSION=$(date +"%Y%m%d")
OUTPUT_DIR="${1:-./mdk-packages}/${BUNDLE_VERSION}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# List of all SDK packages to download
SDK_PACKAGES=(
    # Windows
    "mdk-sdk-windows.7z"
    "mdk-sdk-windows-x64.7z"
    
    # Linux
    "mdk-sdk-linux.tar.xz"
    "mdk-sdk-linux-x64.tar.xz"
    
    # Android
    "mdk-sdk-android.7z"
    
    # Apple (macOS + iOS combined)
    "mdk-sdk-apple.tar.xz"
)

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to download a file
download_file() {
    local filename=$1
    local url="${SOURCEFORGE_BASE_URL}/${filename}/download"
    local output_path="${OUTPUT_DIR}/${filename}"
    
    if [ -f "$output_path" ]; then
        print_warning "File already exists: ${filename}, skipping..."
        return 0
    fi
    
    print_status "Downloading ${filename}..."
    if curl -L -o "$output_path" "$url" --progress-bar; then
        print_status "Successfully downloaded ${filename}"
        return 0
    else
        print_error "Failed to download ${filename}"
        return 1
    fi
}

# Function to generate MD5 checksum
generate_md5() {
    local filename=$1
    local filepath="${OUTPUT_DIR}/${filename}"
    local md5_path="${OUTPUT_DIR}/${filename}.md5"
    
    if [ ! -f "$filepath" ]; then
        print_error "File not found: ${filepath}"
        return 1
    fi
    
    print_status "Generating MD5 for ${filename}..."
    
    # Use md5sum on Linux, md5 on macOS
    if command -v md5sum &> /dev/null; then
        md5sum "$filepath" | awk '{print $1}' > "$md5_path"
    elif command -v md5 &> /dev/null; then
        md5 -r "$filepath" | awk '{print $1}' > "$md5_path"
    else
        print_error "No MD5 tool found (md5sum or md5)"
        return 1
    fi
    
    print_status "MD5 checksum saved to ${filename}.md5"
}

# Export functions and variables for parallel execution
export -f download_file print_status print_error print_warning
export SOURCEFORGE_BASE_URL OUTPUT_DIR RED GREEN YELLOW NC

# Main script
main() {
    echo "=============================================="
    echo "  MDK SDK Download Script"
    echo "=============================================="
    echo ""

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    print_status "Output directory: ${OUTPUT_DIR}"
    echo ""

    # Download all packages (3 at a time in parallel)
    print_status "Downloading ${#SDK_PACKAGES[@]} packages (3 parallel)..."
    echo ""

    printf '%s\n' "${SDK_PACKAGES[@]}" | xargs -P 3 -I {} bash -c 'download_file "$@"' _ {}

    echo ""
    
    # Generate MD5 checksums
    print_status "Generating MD5 checksums..."
    echo ""
    
    for package in "${SDK_PACKAGES[@]}"; do
        if [ -f "${OUTPUT_DIR}/${package}" ]; then
            generate_md5 "$package"
        fi
    done
    
    echo ""
    echo "=============================================="
    echo "  Download Summary"
    echo "=============================================="

    # Count successful downloads
    local downloaded_count=0
    for package in "${SDK_PACKAGES[@]}"; do
        if [ -f "${OUTPUT_DIR}/${package}" ]; then
            ((downloaded_count++))
        fi
    done

    if [ "$downloaded_count" -eq "${#SDK_PACKAGES[@]}" ]; then
        print_status "All ${downloaded_count} downloads completed successfully!"
    else
        print_warning "Downloaded ${downloaded_count}/${#SDK_PACKAGES[@]} packages"
    fi

    echo ""
    print_status "Files saved to: ${OUTPUT_DIR}"
    echo ""
    ls -lh "$OUTPUT_DIR"
}

# Run main function
main

