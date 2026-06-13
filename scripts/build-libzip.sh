#!/bin/bash

cd "$GITHUB_WORKSPACE"
LIBZIP_VER="1.10.1"
wget -q "https://libzip.org/download/libzip-${LIBZIP_VER}.tar.gz"
tar xzf "libzip-${LIBZIP_VER}.tar.gz"
mkdir -p "libzip-${LIBZIP_VER}/build"
cd "libzip-${LIBZIP_VER}/build"
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_ROOT/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="$ABI" \
  -DANDROID_PLATFORM="android-$API" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TOOLS=OFF \
  -DBUILD_REGRESS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_DOC=OFF \
  -DENABLE_ZSTD=OFF \
  -DENABLE_BZIP2=OFF \
  -DENABLE_LZMA=OFF \
  -DENABLE_OPENSSL=OFF \
  -DENABLE_GNUTLS=OFF \
  -DENABLE_MBEDTLS=OFF \
  -DCMAKE_INSTALL_PREFIX="$DEPS_DIR/libzip"
make -j$(nproc)
make install
