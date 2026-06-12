#!/bin/bash

set -e
cd "$GITHUB_WORKSPACE"

# build lzo
wget -q "https://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz"
tar xzf lzo-2.10.tar.gz
cd lzo-2.10
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --prefix="$DEPS_DIR/lzo" --disable-shared --enable-static
make -j$(nproc)
make install
cd "$GITHUB_WORKSPACE"

# build openvpn
wget -q "https://build.openvpn.net/downloads/releases/openvpn-2.6.12.tar.gz"
tar xzf openvpn-2.6.12.tar.gz
cd openvpn-2.6.12
export CFLAGS="$CFLAGS -I$DEPS_DIR/openssl/include -I$DEPS_DIR/lzo/include"
export LDFLAGS="$LDFLAGS -L$DEPS_DIR/openssl/lib -L$DEPS_DIR/lzo/lib"
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --with-crypto-library=openssl \
  --with-ssl="$DEPS_DIR/openssl" \
  --with-lzo="$DEPS_DIR/lzo" \
  --disable-plugin-auth-pam --disable-plugin-down-root \
  --disable-debug --disable-lz4 --disable-dco \
  ac_cv_header_libcap_ng_h=no \
  --disable-shared --enable-static
make -j$(nproc)
$STRIP src/openvpn/openvpn || true
cp src/openvpn/openvpn "$GITHUB_WORKSPACE/artifacts/"
