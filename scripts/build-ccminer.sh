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

# pthread_barrier_t compat for Android API < 24
if [ "$API" -lt 24 ]; then
  cat > compat/pthread_barrier_compat.h << 'FEOF'
#ifndef PTHREAD_BARRIER_COMPAT_H
#define PTHREAD_BARRIER_COMPAT_H
#include <pthread.h>

typedef struct {
  pthread_mutex_t mutex;
  pthread_cond_t cond;
  unsigned int count;
  unsigned int arrived;
} pthread_barrier_t;

static inline int pthread_barrier_init(pthread_barrier_t *b,
                                        const void *attr,
                                        unsigned int count) {
  (void)attr;
  pthread_mutex_init(&b->mutex, NULL);
  pthread_cond_init(&b->cond, NULL);
  b->count = count;
  b->arrived = 0;
  return 0;
}

static inline int pthread_barrier_destroy(pthread_barrier_t *b) {
  pthread_mutex_destroy(&b->mutex);
  pthread_cond_destroy(&b->cond);
  return 0;
}

static inline int pthread_barrier_wait(pthread_barrier_t *b) {
  pthread_mutex_lock(&b->mutex);
  b->arrived++;
  if (b->arrived >= b->count) {
    b->arrived = 0;
    pthread_cond_broadcast(&b->cond);
    pthread_mutex_unlock(&b->mutex);
    return 1;
  }
  pthread_cond_wait(&b->cond, &b->mutex);
  pthread_mutex_unlock(&b->mutex);
  return 0;
}
#endif
FEOF
  export CFLAGS="$CFLAGS -include $PWD/compat/pthread_barrier_compat.h"
fi

# Redirect libcurl pkg-config lookup to our cross-compiled curl
export PKG_CONFIG_PATH="$DEPS_DIR/curl/lib/pkgconfig:$DEPS_DIR/openssl/lib/pkgconfig:$DEPS_DIR/zlib/lib/pkgconfig"

# Pre-set library detection (ccminer uses AC_CHECK_LIB, not --with-*)
export ac_cv_lib_ssl_SSL_free=yes
export ac_cv_lib_crypto_EVP_DigestFinal_ex=yes
export ac_cv_lib_z_gzopen=yes
# pthread is in libc on Android, not a separate lib
export ac_cv_lib_pthread_pthread_create=no
export ac_cv_search_pthread_create=no

# Pass library paths via CPPFLAGS (used by ccminer_CPPFLAGS in Makefile) and LDFLAGS
INCS="-I$DEPS_DIR/openssl/include -I$DEPS_DIR/zlib/include -I$DEPS_DIR/curl/include"
LIBS="-L$DEPS_DIR/openssl/lib -L$DEPS_DIR/zlib/lib -L$DEPS_DIR/curl/lib -lssl -lcrypto -lz -ldl"
export CPPFLAGS="$CPPFLAGS $INCS"
CFLAGS="$CFLAGS $INCS"
LDFLAGS="$LDFLAGS $LIBS"

echo "=== Running configure for ccminer ==="
# Use clang++ for C++ files; pass CXXFLAGS too since ccminer uses it separately from CFLAGS
CXX="${CC%clang}clang++"
CXXFLAGS="$CFLAGS"
# Static link libc++ to avoid needing libc++_shared.so on device
LDFLAGS="$LDFLAGS -static-libstdc++"
./configure --host="$HOST" CC="$CC" CXX="$CXX" CPPFLAGS="$CPPFLAGS" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" \
  --with-cuda=no --enable-openmp
echo "=== configure completed ==="

# Build ccminer with ARMv8 crypto extensions
echo "=== Building ccminer ==="
make -j$(nproc)
$STRIP ccminer 2>/dev/null || true
cp ccminer "$GITHUB_WORKSPACE/artifacts/ccminer-crypto"
# Bundle libomp.so from NDK so it works on device without extra deps
# Match architecture: aarch64 for arm64-v8a, arm for armeabi-v7a
OMP_ARCH="aarch64"
[ "$GOARCH" = "arm" ] && OMP_ARCH="arm"
OMP_SRC=$(find "$NDK_ROOT" -path "*/linux/$OMP_ARCH/libomp.so" -type f 2>/dev/null | head -1)
if [ -n "$OMP_SRC" ]; then
  cp "$OMP_SRC" "$GITHUB_WORKSPACE/artifacts/libomp.so"
  file "$OMP_SRC"
  echo "=== Bundled libomp.so from NDK ==="
else
  echo "=== WARNING: libomp.so not found in NDK for $OMP_ARCH, ccminer may need it installed ==="
fi
echo "=== ccminer build done ==="
