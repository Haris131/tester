#!/bin/bash

set -e
cd "$GITHUB_WORKSPACE"

# cpuminer-opt only supports aarch64
if [ "$GOARCH" != "arm64" ]; then
  echo "Skipping cpuminer-opt on non-arm64 arch ($GOARCH)"
  exit 0
fi

GMP_VER=6.3.0

rm -rf cpuminer-opt gmp-$GMP_VER
git clone --depth=1 https://github.com/JayDDee/cpuminer-opt.git
echo "=== cpuminer-opt cloned successfully ==="

# Build GMP (needed by cpuminer-opt)
echo "=== Building GMP $GMP_VER ==="
curl -sL --connect-timeout 30 --max-time 120 --retry 3 --retry-delay 5 \
  https://gmplib.org/download/gmp/gmp-$GMP_VER.tar.xz -o /tmp/gmp.tar.xz || \
curl -sL --connect-timeout 30 --max-time 120 \
  https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VER.tar.xz -o /tmp/gmp.tar.xz
tar xJf /tmp/gmp.tar.xz
cd gmp-$GMP_VER
ABI=64 ./configure --host="$HOST" CC="$CC" AR="$AR" RANLIB="$RANLIB" --disable-shared --enable-static --prefix="$GITHUB_WORKSPACE/deps/gmp"
make -j$(nproc)
make install
echo "=== GMP build done ==="

cd "$GITHUB_WORKSPACE/cpuminer-opt"

# Run autogen to generate configure script
./autogen.sh
echo "=== autogen completed ==="

# Set up library paths (reuse existing deps from workflow)
export PKG_CONFIG_PATH="$DEPS_DIR/curl/lib/pkgconfig:$DEPS_DIR/openssl/lib/pkgconfig:$DEPS_DIR/zlib/lib/pkgconfig"

INCS="-I$DEPS_DIR/openssl/include -I$DEPS_DIR/zlib/include -I$DEPS_DIR/curl/include -I$GITHUB_WORKSPACE/deps/gmp/include"
LIBS="-L$DEPS_DIR/openssl/lib -L$DEPS_DIR/zlib/lib -L$DEPS_DIR/curl/lib -L$GITHUB_WORKSPACE/deps/gmp/lib"
export CPPFLAGS="$CPPFLAGS $INCS"

# Architecture & optimization flags (same as ccminer)
ARCH_OPTS="-march=armv8-a+crypto+sha2+crc -mtune=cortex-a73"
PERF_OPTS="-Ofast -fstrict-aliasing -ftree-vectorize -funroll-loops -finline-functions -fomit-frame-pointer -falign-functions=64"

# Use clang for both CC and CXX
CXX="${CC%clang}clang++"

echo "=== Running configure for cpuminer-opt ==="
CFLAGS="$CFLAGS $ARCH_OPTS $PERF_OPTS $INCS" \
CXXFLAGS="$CXXFLAGS $ARCH_OPTS $PERF_OPTS $INCS" \
LDFLAGS="$LDFLAGS $LIBS" \
./configure \
  --host="$HOST" \
  CC="$CC" CXX="$CXX" \
  --with-curl="$DEPS_DIR/curl"
echo "=== configure completed ==="

# Add LTO and static flags to Makefile post-configure
sed -i '/^CFLAGS[[:space:]]*=/s/$/ -flto/' Makefile
sed -i '/^CXXFLAGS[[:space:]]*=/s/$/ -flto/' Makefile
sed -i '/^LDFLAGS[[:space:]]*=/s/$/ -flto -fuse-ld=lld -static-libstdc++ -static-openmp/' Makefile
sed -i '/^cpuminer_LDADD[[:space:]]*=/s/$/ -lssl -lcrypto/' Makefile
echo "=== patched Makefile with LTO/static flags ==="

echo "=== Building cpuminer-opt ==="
make -j$(nproc)
$STRIP cpuminer 2>/dev/null || true
cp cpuminer "$GITHUB_WORKSPACE/artifacts/cpuminer-opt"
echo "=== cpuminer-opt build done ==="
