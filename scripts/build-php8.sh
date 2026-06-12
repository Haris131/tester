#!/bin/bash

cd "$GITHUB_WORKSPACE"
PHP_VER="$PHP_VERSION"
wget -q "https://www.php.net/distributions/php-${PHP_VER}.tar.gz"
tar xzf "php-${PHP_VER}.tar.gz"
cd "php-${PHP_VER}"
export CFLAGS="$CFLAGS -I$DEPS_DIR/openssl/include -I$DEPS_DIR/zlib/include"
export LDFLAGS="$LDFLAGS -L$DEPS_DIR/openssl/lib -L$DEPS_DIR/zlib/lib"
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --disable-all --without-pear --enable-sockets --enable-pcntl --enable-session \
  --disable-phpdbg --disable-cgi --disable-fpm \
  --with-openssl="$DEPS_DIR/openssl" --with-zlib="$DEPS_DIR/zlib" \
  --with-config-file-scan-dir=/data/data/com.termux/files/usr/etc/php.d
sed -i '/#define HAVE_RES_NSEARCH/d;/#define HAVE___RES_NSEARCH/d' main/php_config.h
sed -i '/#define HAVE_DN_SKIPNAME/d;/#define HAVE___DN_SKIPNAME/d' main/php_config.h
cat > php-stubs.c << 'STUBEOF'
#include <stddef.h>
#include <wchar.h>
#include <string.h>
#include <unistd.h>
#include <locale.h>
int mblen(const char *s, size_t n) { static mbstate_t _ms; if (!s) { memset(&_ms, 0, sizeof(_ms)); return 0; } return mbrlen(s, n, &_ms); }
int getdtablesize(void) { return sysconf(_SC_OPEN_MAX); }
struct lconv *localeconv(void) { static struct lconv _lc; return &_lc; }
void zif_dns_get_record(void *d, void *rv) { }
void zif_dns_get_mx(void *d, void *rv) { }
STUBEOF
$CC $CFLAGS -c -o php-stubs.o php-stubs.c
$AR rcs libphp-stubs.a php-stubs.o
sed -i 's|^EXTRA_LIBS =|EXTRA_LIBS = '"$PWD"'/libphp-stubs.a |' Makefile
make -j$(nproc)
$STRIP sapi/cli/php || true
cp sapi/cli/php "$GITHUB_WORKSPACE/artifacts/php8" 2>/dev/null || true
