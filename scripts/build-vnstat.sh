#!/bin/bash

set -e
cd "$GITHUB_WORKSPACE"

# build sqlite3
wget -q "https://www.sqlite.org/2024/sqlite-autoconf-3460000.tar.gz"
tar xzf sqlite-autoconf-3460000.tar.gz
cd sqlite-autoconf-3460000
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --prefix="$DEPS_DIR/sqlite" --disable-shared --enable-static
make -j$(nproc)
make install
cd "$GITHUB_WORKSPACE"

# build vnstat
wget -q "https://github.com/vergoh/vnstat/releases/download/v2.12/vnstat-2.12.tar.gz"
tar xzf vnstat-2.12.tar.gz
cd vnstat-2.12
export CFLAGS="$CFLAGS -I$DEPS_DIR/sqlite/include"
export LDFLAGS="$LDFLAGS -L$DEPS_DIR/sqlite/lib"
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --disable-shared --enable-static --disable-nls --enable-imageoutput=no \
  --with-sqlite3="$DEPS_DIR/sqlite"
sed -i 's/lockf(pidfile, F_TLOCK, 0)/flock(pidfile, LOCK_EX | LOCK_NB)/' src/daemon.c
sed -i 's/for (i = getdtablesize(); i >= 0; --i)/for (i = sysconf(_SC_OPEN_MAX); i >= 0; --i)/' src/daemon.c
make -j$(nproc)
$STRIP src/vnstatd src/vnstat 2>/dev/null || true
cp src/vnstatd src/vnstat "$GITHUB_WORKSPACE/artifacts/" 2>/dev/null || true
