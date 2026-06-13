#!/bin/bash

cd "$GITHUB_WORKSPACE"
ONIG_VER="6.9.9"
wget -q "https://github.com/kkos/oniguruma/releases/download/v${ONIG_VER}/onig-${ONIG_VER}.tar.gz"
tar xzf "onig-${ONIG_VER}.tar.gz"
cd "onig-${ONIG_VER}"
./configure --host="$HOST" CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --enable-static --disable-shared \
  --prefix="$DEPS_DIR/oniguruma"
make -j$(nproc)
make install
