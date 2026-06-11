#!/bin/bash
set -e
cd "$GITHUB_WORKSPACE"
wget -q "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz" -O "zlib-${ZLIB_VERSION}.tar.gz"
tar xzf "zlib-${ZLIB_VERSION}.tar.gz"
cd "zlib-${ZLIB_VERSION}"
CHOST="$HOST" CC="$CC" AR="$AR" RANLIB="$RANLIB" ./configure --prefix="$DEPS_DIR/zlib" --static
make -j$(nproc)
make install
