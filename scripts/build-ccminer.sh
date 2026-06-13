#!/bin/bash

set -e
cd "$GITHUB_WORKSPACE"

# ccminer uses ARMv8 crypto extensions (aarch64 only)
if [ "$GOARCH" != "arm64" ]; then
  echo "Skipping ccminer on non-arm64 arch ($GOARCH)"
  exit 0
fi

rm -rf ccminer
git clone --depth=1 https://github.com/Darktron/ccminer.git
cd ccminer
echo "=== ccminer cloned successfully ==="

[ -d compat/jansson ] || mkdir -p compat/jansson

# Pre-create jansson config headers for cross-compilation
cat > compat/jansson/jansson_config.h << 'FEOF'
#ifndef JANSSON_CONFIG_H
#define JANSSON_CONFIG_H
#ifdef __cplusplus
#define JSON_INLINE inline
#else
#define JSON_INLINE inline
#endif
#define JSON_INTEGER_IS_LONG_LONG 1
#define JSON_HAVE_LOCALECONV 1
#endif
FEOF

cat > compat/jansson/jansson_private_config.h << 'FEOF'
#define HAVE_CLOSE 1
#define HAVE_FCNTL_H 1
#define HAVE_GETPID 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_INTTYPES_H 1
#define HAVE_LOCALECONV 1
#define HAVE_LOCALE_H 1
#define HAVE_LONG_LONG_INT 1
#define HAVE_MEMORY_H 1
#define HAVE_OPEN 1
#define HAVE_READ 1
#define HAVE_SCHED_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_STRTOLL 1
#define HAVE_SYNC_BUILTINS 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define STDC_HEADERS 1
#define USE_URANDOM 1
#define LT_OBJDIR ".libs/"
#define PACKAGE "jansson"
#define PACKAGE_BUGREPORT "petri@digip.org"
#define PACKAGE_NAME "jansson"
#define PACKAGE_STRING "jansson 2.6"
#define PACKAGE_TARNAME "jansson"
#define PACKAGE_URL ""
#define PACKAGE_VERSION "2.6"
#define VERSION "2.6"
FEOF

# Force bundled jansson
export ac_cv_lib_jansson_json_loads=no

# Redirect libcurl pkg-config lookup to our cross-compiled curl
export PKG_CONFIG_PATH="$DEPS_DIR/curl/lib/pkgconfig:$DEPS_DIR/openssl/lib/pkgconfig:$DEPS_DIR/zlib/lib/pkgconfig"

# Pre-set library detection (ccminer uses AC_CHECK_LIB, not --with-*)
export ac_cv_lib_ssl_SSL_free=yes
export ac_cv_lib_crypto_EVP_DigestFinal_ex=yes
export ac_cv_lib_z_gzopen=yes
export ac_cv_lib_pthread_pthread_create=yes

# Pass library paths via CPPFLAGS (used by ccminer_CPPFLAGS in Makefile) and LDFLAGS
INCS="-I$DEPS_DIR/openssl/include -I$DEPS_DIR/zlib/include -I$DEPS_DIR/curl/include"
LIBS="-L$DEPS_DIR/openssl/lib -L$DEPS_DIR/zlib/lib -L$DEPS_DIR/curl/lib -lssl -lcrypto -lz -ldl"
export CPPFLAGS="$CPPFLAGS $INCS"
CFLAGS="$CFLAGS $INCS"
LDFLAGS="$LDFLAGS $LIBS"

echo "=== Running configure for ccminer ==="
./configure --host="$HOST" CC="$CC" CXX="${CXX:-$CC}" CPPFLAGS="$CPPFLAGS" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --with-cuda=no --enable-openmp
echo "=== configure completed ==="

# Build crypto version first (uses default -march=armv8-a+crypto from Makefile)
echo "=== Building crypto version (A55/A73+) ==="
make -j$(nproc)
$STRIP ccminer 2>/dev/null || true
cp ccminer "$GITHUB_WORKSPACE/artifacts/ccminer-crypto"
echo "=== Crypto build done ==="

# Build baseline (A53 compatible — no ARMv8 crypto extensions)
echo "=== Building baseline (A53) ==="
make clean 2>/dev/null || true
# Replace march in multi-line Makefile variable
sed -i '/^ccminer_CPPFLAGS /,/^[^	]/s/-march=armv8-a+crypto/-march=armv8-a/' Makefile
make -j$(nproc)
$STRIP ccminer 2>/dev/null || true
cp ccminer "$GITHUB_WORKSPACE/artifacts/ccminer"
echo "=== Baseline build done ==="
