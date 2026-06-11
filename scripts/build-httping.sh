#!/bin/bash

cd "$GITHUB_WORKSPACE"
wget -q "https://github.com/folkertvanheusden/httping/archive/refs/tags/v${HTTPING_VERSION}.tar.gz" -O "httping-${HTTPING_VERSION}.tar.gz"
tar xzf "httping-${HTTPING_VERSION}.tar.gz"
HTTPING_DIR=$(ls -d *${HTTPING_VERSION}/ | head -1)
cd "$HTTPING_DIR"
touch makefile.inc
printf '%s\n' '#pragma once' '#define HAVE_SSL 1' '#define HAVE_OPENSSL 1' "#define VERSION \"${HTTPING_VERSION}\"" > config.h
printf '%s\n' '#define gettext(s) s' '#define dgettext(d,s) s' '#define bindtextdomain(d,p)' '#define textdomain(d)' > libintl.h
printf '%s\n' '#include <openssl/engine.h>' 'void ENGINE_cleanup(void) {}' > stub-engine.c
export CFLAGS="$CFLAGS -I. -I$DEPS_DIR/openssl/include"
export LDFLAGS="$LDFLAGS -L$DEPS_DIR/openssl/lib -lssl -lcrypto -lz -ldl ./stub-engine.o"
$CC $CFLAGS -c -o stub-engine.o stub-engine.c
make CC="$CC" NO_GETTEXT=yes SSL=yes -j$(nproc)
$STRIP httping
cp httping "$GITHUB_WORKSPACE/artifacts/"
