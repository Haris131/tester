#!/bin/bash
set -e
cd "$GITHUB_WORKSPACE"
wget -q "https://curl.se/download/curl-${CURL_VERSION}.tar.gz"
tar xzf "curl-${CURL_VERSION}.tar.gz"
cd "curl-${CURL_VERSION}"
export CFLAGS="$CFLAGS -I$DEPS_DIR/zlib/include -I$DEPS_DIR/openssl/include"
export LDFLAGS="$LDFLAGS -L$DEPS_DIR/zlib/lib -L$DEPS_DIR/openssl/lib"
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --with-openssl="$DEPS_DIR/openssl" --with-zlib="$DEPS_DIR/zlib" \
  --disable-shared --enable-static --disable-docs --disable-manual \
  --without-brotli --without-zstd --without-libpsl \
  --enable-ipv6 --enable-threaded-resolver
make -j$(nproc)
$STRIP src/curl
cp src/curl "$GITHUB_WORKSPACE/artifacts/"
