#!/bin/bash

cd "$GITHUB_WORKSPACE"
ONIG_VER="6.9.9"
wget -q "https://github.com/kkos/oniguruma/archive/refs/tags/v${ONIG_VER}.tar.gz" -O "oniguruma-${ONIG_VER}.tar.gz"
tar xzf "oniguruma-${ONIG_VER}.tar.gz"
cd "oniguruma-${ONIG_VER}" 2>/dev/null || cd "oniguruma-v${ONIG_VER}"
./configure --host="$HOST" CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --enable-static --disable-shared \
  --prefix="$DEPS_DIR/oniguruma"
make -j$(nproc)
make install
