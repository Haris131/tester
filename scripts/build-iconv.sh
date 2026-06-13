#!/bin/bash

cd "$GITHUB_WORKSPACE"
ICONV_VER="1.17"
wget -q "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${ICONV_VER}.tar.gz"
tar xzf "libiconv-${ICONV_VER}.tar.gz"
cd "libiconv-${ICONV_VER}"
./configure --host="$HOST" CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --enable-static --disable-shared \
  --prefix="$DEPS_DIR/iconv"
make -j$(nproc)
make install
