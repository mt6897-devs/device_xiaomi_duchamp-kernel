#!/bin/sh

# Script to copy modules quickly from mtk bazel kernel builds
# Brought to you by: rio004
#

GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

KERNEL_DIR="$1"
SRC_DIR="$KERNEL_DIR/out/dist/"

SOC="mt6897"

[ -z "$KERNEL_DIR" ] && { echo "Usage: $0 /path/to/kernel/"; exit 1; }
[ ! -d "$KERNEL_DIR" ] && { echo "${RED}Invalid KERNEL_DIR:${RESET} $KERNEL_DIR"; exit 1; }

mkdir -p modules dtb

MODULE_LISTS="
    modules/system_dlkm.modules.load
    modules/vendor_dlkm.modules.load
    modules/vendor_ramdisk.modules.load
    modules/vendor_ramdisk.modules.load.recovery
"

EXTRA_MODULES="
    gps_drv_dl_v051.ko
    gps_pwr.ko
    gps_scp.ko
"

copy_module() {
    mod="$1"
    found=$(find "$SRC_DIR" -type f -name "$mod" -print -quit)
    if [ -n "$found" ]; then
        cp "$found" "./modules/"
        chmod -x "./modules/$(basename "$found")"
        echo "${GREEN}Copied:${RESET} $mod"
    else
        echo "${RED}Missing:${RESET} $mod"
    fi
}

# Copy modules from lists
for modules_list in $MODULE_LISTS; do
    if [ ! -f "$modules_list" ]; then
        echo "${RED}Missing list:${RESET} $modules_list"
        continue
    fi
    while read -r mod; do
        [ -z "$mod" ] && continue
        case "$mod" in \#*) continue ;; esac
        copy_module "$mod"
    done < "$modules_list"
done

# Copy extra modules
for mod in $EXTRA_MODULES; do
    copy_module "$mod"
done

# Strip symbols
CLANG_VERISON=clang-r487747c
find ./modules -name '*.ko' \
    -exec ${KERNEL_DIR}/prebuilts/clang/host/linux-x86/${CLANG_VERISON}/bin/llvm-strip --strip-debug {} +

# Kernel artifacts
for artifact in Image.lz4 kernel-uapi-headers.tar.gz; do
    found=$(find "$SRC_DIR" -type f -name "$artifact" -print -quit)
    if [ -n "$found" ]; then
        cp "$found" ./ 
        chmod -x "./$(basename "$found")"
        echo "${GREEN}Copied:${RESET} $(basename "$found")"
    else
        echo "${RED}Missing:${RESET} $artifact"
    fi
done

# DTBs
dtbs=$(find "$SRC_DIR" -type f -name "${SOC}.dtb" -print -quit)
if [ -n "$dtbs" ]; then
    for dtb in $dtbs; do
        cp "$dtb" ./dtb/
        chmod -x "./dtb/$(basename "$dtb")"
        echo "${GREEN}Copied:${RESET} $(basename "$dtb")"
    done
else
    echo "${RED}Missing:${RESET} ${SOC}.dtb"
fi
