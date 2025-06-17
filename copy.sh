#!/bin/bash

set -e

# Debug/helper functions
info() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

show_help() {
    cat <<EOF
Usage: $0 ROOT_DIR

This script copies kernel components and modules from the build output directory.

Arguments:
  ROOT_DIR - Path to the root directory containing build outputs
EOF
}

# Validate input
if [ $# -ne 1 ]; then
    error "Please provide the root directory as an argument"
    show_help
    exit 1
fi

ROOT_DIR="$1"

# Config paths
DIST_DIR="${ROOT_DIR}/out/dist/kernel_device_modules-6.1/mgk_64_k61_kernel_aarch64.user"
MTK_DIST_DIR="${ROOT_DIR}/out/dist/kernel_device_modules-6.1/mgk_64_k61.user"
CUSTOMER_MODULES_DIR="${ROOT_DIR}/out/dist/kernel_device_modules-6.1/mgk_64_k61_customer_modules_install.user"
CLANG_VERISON=clang-r487747c
STRIP_BIN="${ROOT_DIR}/prebuilts/clang/host/linux-x86/${CLANG_VERISON}/bin/llvm-strip"

# Validate directories exist
for dir in "$DIST_DIR" "$MTK_DIST_DIR" "$CUSTOMER_MODULES_DIR"; do
    if [ ! -d "$dir" ]; then
        error "Directory not found: $dir"
        exit 1
    fi
done

# Validate strip binary exists
if [ ! -x "$STRIP_BIN" ]; then
    error "Strip binary not found or not executable: $STRIP_BIN"
    exit 1
fi

# Create target directories if they don't exist
for TARGET in system vendor vendor_ramdisk; do
    mkdir -p "$TARGET"
done

# Kernel operations
info "Copying kernel & DTB..."
cp "$DIST_DIR/Image.lz4" ./ || error "Failed to copy Image.lz4"
mv Image.lz4 kernel || error "Failed to rename kernel image"
chmod -x kernel

# Copy Modules
for TARGET in system vendor vendor_ramdisk; do
    info "Copying GKI modules to $TARGET..."
    find "$DIST_DIR" -type f -name '*.ko' -exec cp {} "$TARGET/" \;
    cp $CUSTOMER_MODULES_DIR/* $TARGET
done

# Remove unused modules
info "Running git clean..."
git clean -f system/ >/dev/null
git clean -f vendor/ >/dev/null
git clean -f vendor_ramdisk/ >/dev/null

# Strip the modules
info "Stripping debug symbols from modules..."
find . -type f -name '*.ko' -exec "$STRIP_BIN" --strip-debug {} +

info "Operation completed successfully."
