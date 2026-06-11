#!/bin/bash

cd "$GITHUB_WORKSPACE"
curl -fSL -o "stunnel-${STUNNEL_VERSION}.tar.gz" https://www.stunnel.org/downloads/stunnel-${STUNNEL_VERSION}.tar.gz || \
curl -fSL -o "stunnel-${STUNNEL_VERSION}.tar.gz" https://www.usenix.org.uk/mirrors/stunnel/archive/5.x/stunnel-${STUNNEL_VERSION}.tar.gz || \
curl -fSL -o "stunnel-${STUNNEL_VERSION}.tar.gz" https://fossies.org/linux/misc/stunnel-${STUNNEL_VERSION}.tar.gz
tar xzf "stunnel-${STUNNEL_VERSION}.tar.gz"
cd "stunnel-${STUNNEL_VERSION}"
export CFLAGS="$CFLAGS -I$DEPS_DIR/openssl/include"
export LDFLAGS="$LDFLAGS -L$DEPS_DIR/openssl/lib -ldl"
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --with-ssl="$DEPS_DIR/openssl" --disable-systemd --disable-fips \
  ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
make -j$(nproc)
$STRIP src/stunnel
cp src/stunnel "$GITHUB_WORKSPACE/artifacts/"
