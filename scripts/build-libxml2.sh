#!/bin/bash

cd "$GITHUB_WORKSPACE"
LIBXML2_VER="2.12.9"
LIBXML2_SERIES="2.12"
wget -q "https://download.gnome.org/sources/libxml2/${LIBXML2_SERIES}/libxml2-${LIBXML2_VER}.tar.xz"
tar xf "libxml2-${LIBXML2_VER}.tar.xz"
cd "libxml2-${LIBXML2_VER}"
export CFLAGS="$CFLAGS -I$DEPS_DIR/zlib/include"
export LDFLAGS="$LDFLAGS -L$DEPS_DIR/zlib/lib"
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --enable-static --disable-shared \
  --prefix="$DEPS_DIR/libxml2" \
  --without-python --without-iconv --without-lzma \
  --with-zlib="$DEPS_DIR/zlib"
make -j$(nproc)
make install
