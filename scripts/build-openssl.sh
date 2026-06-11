#!/bin/bash

cd "$GITHUB_WORKSPACE"
wget -q "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
tar xzf "openssl-${OPENSSL_VERSION}.tar.gz"
cd "openssl-${OPENSSL_VERSION}"
export PATH="$NDK_BIN:$PATH"
export CC="$CC"
export AR="$AR"
export RANLIB="$RANLIB"
OPENSSL_OPTS="no-shared no-asm no-engine"
if [ "$OPENSSL_VERSION" = "1.1.1w" ]; then
  OPENSSL_OPTS="$OPENSSL_OPTS no-hw"
fi
./Configure "$OPENSSL_TARGET" --prefix="$DEPS_DIR/openssl" $OPENSSL_OPTS -D__ANDROID_API__=$API -DOPENSSL_NO_SECURE_MEMORY
make -j$(nproc)
make install_sw
