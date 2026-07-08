#!/usr/bin/env bash
# Build libopentui.so for Android aarch64
#
# Usage: ./scripts/build-opentui.sh
#
# OpenCode's TUI renderer (@opentui/core) uses a native Zig library.
# The upstream build targets aarch64-linux (musl), which fails on Android
# because getauxval cannot be resolved. We build for aarch64-linux-android.29
# with NDK's libc.so for Bionic compatibility.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Use Bun's vendored Zig if available, otherwise fall back to PATH
if [ -z "${ZIG_BIN:-}" ] && [ -f "$BUN_SRC/vendor/zig/zig" ]; then
  ZIG_BIN="$BUN_SRC/vendor/zig/zig"
elif [ -z "${ZIG_BIN:-}" ]; then
  ZIG_BIN="zig"
fi

echo "=== Building libopentui.so for Android aarch64 ==="

# Clone opentui if needed
if [ ! -d "$OPENTUI_SRC/.git" ]; then
    echo ">>> Cloning opentui at commit ${OPENTUI_COMMIT}..."
    mkdir -p "$OPENTUI_SRC"
    cd "$OPENTUI_SRC"
    git init
    git remote add origin https://github.com/anomalyco/opentui.git
    git fetch --depth=1 origin "${OPENTUI_COMMIT}"
    git checkout FETCH_HEAD
else
    echo ">>> opentui source exists at $OPENTUI_SRC"
fi

# Apply Android patches:
#   1. android-libc-link.patch: skips linkLibC/linkLibCpp for Android,
#      provides NDK paths and links system libs manually instead.
echo ">>> Resetting opentui source files to pristine state..."
cd "$OPENTUI_SRC"
git checkout -- packages/core/src/zig/ 2>/dev/null || true

for patch in \
    "$REPO_ROOT/patches/opentui/android-libc-link.patch"
do
    if [ -f "$patch" ]; then
        patch_name=$(basename "$patch")
        echo ">>> Applying opentui patch: $patch_name..."
        if git apply --check "$patch" 2>/dev/null; then
            git apply "$patch"
            echo "    $patch_name applied successfully"
        else
            echo "    ERROR: $patch_name does not apply cleanly"
            exit 1
        fi
    fi
done

# Copy errno_shim.c for Android builds (provides __errno_location symbol)
# Bionic libc does not export __errno_location as a shared symbol, but
# glibc/musl-compiled C++ code may reference it. This shim provides it.
if [ -f "$REPO_ROOT/patches/opentui/android_shim.c" ]; then
    cp "$REPO_ROOT/patches/opentui/android_shim.c" "$OPENTUI_SRC/packages/core/src/zig/"
    echo "    Copied android_shim.c"
fi
if [ -f "$REPO_ROOT/patches/opentui/locale_shim.h" ]; then
    cp "$REPO_ROOT/patches/opentui/locale_shim.h" "$OPENTUI_SRC/packages/core/src/zig/"
    echo "    Copied locale_shim.h"
fi

OPENTUI_ZIG_DIR="$OPENTUI_SRC/packages/core/src/zig"

if [ ! -f "$OPENTUI_ZIG_DIR/build.zig" ]; then
    echo "ERROR: build.zig not found at $OPENTUI_ZIG_DIR"
    exit 1
fi

echo ">>> Building with Zig (target: aarch64-linux-android.29)..."

# Diagnostic: check NDK C++ headers location
echo ">>> Checking NDK C++ headers..."
NDK_TC="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"
for p in "$NDK_TC/include/c++/v1" "$NDK_TC/include/c++" "$NDK_TC/sysroot/usr/include/c++/v1"; do
    if [ -f "$p/type_traits" ]; then
        echo "    Found type_traits at: $p/type_traits"
    fi
done
find "$NDK_TC" -name "type_traits" -maxdepth 6 2>/dev/null | head -5 || true

# Pre-compile yoga C++ with NDK clang++ for Android builds
# The yoga dependency requires linkLibCpp() which fails on Android with Zig.
# We pre-compile yoga as a static library and link it manually.
YOGA_LIB_DIR="$OPENTUI_SRC/build-android-yoga"
mkdir -p "$YOGA_LIB_DIR"

if [ ! -f "$YOGA_LIB_DIR/libyoga.a" ]; then
    echo ">>> Pre-compiling yoga C++ for Android aarch64..."

    # Clone yoga source if not present
    YOGA_SRC="$WORK_DIR/yoga-src"
    if [ ! -d "$YOGA_SRC" ]; then
        echo "    Cloning yoga v3.2.1..."
        git clone --depth=1 --branch v3.2.1 https://github.com/facebook/yoga.git "$YOGA_SRC"
    fi

    YOGA_CXX_SOURCES=(
        "yoga/YGConfig.cpp"
        "yoga/YGEnums.cpp"
        "yoga/YGNode.cpp"
        "yoga/YGNodeLayout.cpp"
        "yoga/YGNodeStyle.cpp"
        "yoga/YGPixelGrid.cpp"
        "yoga/YGValue.cpp"
        "yoga/algorithm/AbsoluteLayout.cpp"
        "yoga/algorithm/Baseline.cpp"
        "yoga/algorithm/Cache.cpp"
        "yoga/algorithm/CalculateLayout.cpp"
        "yoga/algorithm/FlexLine.cpp"
        "yoga/algorithm/PixelGrid.cpp"
        "yoga/config/Config.cpp"
        "yoga/debug/AssertFatal.cpp"
        "yoga/debug/Log.cpp"
        "yoga/event/event.cpp"
        "yoga/node/LayoutResults.cpp"
        "yoga/node/Node.cpp"
    )

    YOGA_CXX="$NDK_TC/bin/aarch64-linux-android${ANDROID_API}-clang++"
    YOGA_AR="$NDK_TC/bin/llvm-ar"
    YOGA_OBJS=()

    for src in "${YOGA_CXX_SOURCES[@]}"; do
        obj="$YOGA_LIB_DIR/$(basename $src .cpp).o"
        $YOGA_CXX -std=c++20 -fexceptions -frtti -fPIC -O2 \
            -I"$YOGA_SRC" \
            -c "$YOGA_SRC/$src" \
            -o "$obj" 2>&1
        if [ $? -ne 0 ]; then
            echo "    FAILED: $src"
            exit 1
        fi
        YOGA_OBJS+=("$obj")
    done

    $YOGA_AR rcs "$YOGA_LIB_DIR/libyoga.a" "${YOGA_OBJS[@]}"
    echo "    libyoga.a built: $(du -h "$YOGA_LIB_DIR/libyoga.a" | cut -f1)"
else
    echo ">>> Using pre-built libyoga.a at $YOGA_LIB_DIR"
fi

# Ensure ANDROID_API is at least 29 (Zig's requiresLibC returns false for API >= 29,
# preventing the libc provision error in Config.resolve)
if [ "${ANDROID_API:-24}" -lt 29 ]; then
    export ANDROID_API=29
fi

# Create a libc paths file for Zig's --libc flag
# This allows linkLibC() to find bionic (Android's libc) through the NDK
NDK_TC="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"
NDK_SYS="${NDK_TC}/sysroot"
ANDROID_LIBC_FILE="${WORK_DIR}/android-aarch64-libc.txt"
cat > "$ANDROID_LIBC_FILE" << EOF
include_dir=${NDK_SYS}/usr/include
sys_include_dir=${NDK_SYS}/usr/include/aarch64-linux-android
crt_dir=${NDK_SYS}/usr/lib/aarch64-linux-android/${ANDROID_API}
msvc_lib_dir=
kernel32_lib_dir=
gcc_dir=
EOF
echo "    Created libc paths file: $ANDROID_LIBC_FILE"
"$ZIG_BIN" libc "$ANDROID_LIBC_FILE" 2>&1 || echo "    WARNING: libc file validation failed"

# Ensure both NDK env vars are set for Zig's native NDK auto-detection
export ANDROID_NDK_ROOT="${ANDROID_NDK_HOME}"
export YOGA_LIB_PATH="$YOGA_LIB_DIR"
export ANDROID_LIBC_FILE="$ANDROID_LIBC_FILE"

cd "$OPENTUI_ZIG_DIR"

"$ZIG_BIN" build \
    -Dtarget=aarch64-linux-android.29 \
    -Doptimize=ReleaseFast \
    --prefix . 2>&1

# The build.zig installs to dest_dir="../lib/{output_name}" relative to
# the --prefix dir.  With --prefix=. (= OPENTUI_ZIG_DIR), the .so ends
# up one directory above: packages/core/src/lib/aarch64-linux-android/
LIBOPENTUI="$OPENTUI_ZIG_DIR/../lib/aarch64-linux-android.29/libopentui.so"
if [ ! -f "$LIBOPENTUI" ]; then
    echo "ERROR: libopentui.so not found"
    echo "  Expected at: $LIBOPENTUI"
    echo "  Searching for any libopentui.so under opentui-src..."
    find "$OPENTUI_SRC" -name "libopentui.so" -type f 2>/dev/null || true
    exit 1
fi

echo ""
echo "=== libopentui.so build complete ==="
echo "Output: $LIBOPENTUI"
echo "Size: $(du -h "$LIBOPENTUI" | cut -f1)"
file "$LIBOPENTUI"

# Verify the .so has NEEDED: libc.so (required for Android dlopen)
if readelf -d "$LIBOPENTUI" 2>/dev/null | grep -q "NEEDED.*libc.so"; then
    echo "OK: libopentui.so has NEEDED: libc.so (required for Android)"
else
    echo "ERROR: libopentui.so is missing NEEDED: libc.so dependency"
    echo "       Android dlopen() will fail without this."
    echo "       Ensure ANDROID_NDK_HOME is set and the opentui patch was applied."
    readelf -d "$LIBOPENTUI" 2>/dev/null | grep NEEDED || echo "       (no NEEDED entries found)"
    exit 1
fi
