#!/bin/bash

cd "$GITHUB_WORKSPACE"
wget -q "https://github.com/ambrop72/badvpn/archive/refs/tags/${BADVPN_VERSION}.tar.gz" -O badvpn.tar.gz
tar xzf badvpn.tar.gz
sed -i 's/elseif (CMAKE_SYSTEM_NAME STREQUAL "Linux")/elseif (CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_SYSTEM_NAME STREQUAL "Android")/' "badvpn-${BADVPN_VERSION}/CMakeLists.txt"
mkdir -p "$DEPS_DIR"
$AR rcs "$DEPS_DIR/librt.a"
cd "badvpn-${BADVPN_VERSION}"
mkdir build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$NDK_ROOT/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-$API \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_TUN2SOCKS=1 \
  -DCMAKE_EXE_LINKER_FLAGS="-L$DEPS_DIR"
make
TUN=$(find . -name "badvpn-tun2socks" -type f | head -1)
$STRIP "$TUN"
cp "$TUN" "$GITHUB_WORKSPACE/artifacts/"
