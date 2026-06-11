#!/bin/bash

cd "$GITHUB_WORKSPACE"
wget -q https://deb.debian.org/debian/pool/main/c/corkscrew/corkscrew_2.0.orig.tar.gz -O corkscrew-2.0.tar.gz 2>&1 || \
wget -q http://ftp.debian.org/debian/pool/main/c/corkscrew/corkscrew_2.0.orig.tar.gz -O corkscrew-2.0.tar.gz 2>&1 || \
wget -q http://corkscrew.agroman.net/corkscrew-2.0.tar.gz -O corkscrew-2.0.tar.gz 2>&1
tar xzf corkscrew-2.0.tar.gz
cd corkscrew-2.0
CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes \
  ./configure --host="$HOST"
make -j$(nproc)
$STRIP corkscrew
cp corkscrew "$GITHUB_WORKSPACE/artifacts/"
