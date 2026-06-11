#!/bin/bash
set -e
cd "$GITHUB_WORKSPACE"
wget -q https://sourceforge.net/projects/sshpass/files/sshpass/1.10/sshpass-1.10.tar.gz
tar xzf sshpass-1.10.tar.gz
cd sshpass-1.10
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
make -j$(nproc)
$STRIP sshpass
cp sshpass "$GITHUB_WORKSPACE/artifacts/"
