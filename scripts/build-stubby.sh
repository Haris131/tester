#!/bin/bash
set -e
cd "$GITHUB_WORKSPACE"
git clone --depth 1 --branch "$GETDNS_VERSION" --recurse-submodules https://github.com/getdnsapi/getdns.git "getdns-${GETDNS_VERSION}"
cat > bsd_signal_stub.c << 'EOF'
#include <signal.h>
void (*bsd_signal(int sig, void (*func)(int)))(int) { return signal(sig, func); }
EOF
$CC -c -o bsd_signal_stub.o bsd_signal_stub.c
$AR rcs libbsd_signal_stub.a bsd_signal_stub.o
cd "getdns-${GETDNS_VERSION}"
mkdir build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$NDK_ROOT/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-$API -DANDROID_STL=none \
  -DCMAKE_INSTALL_PREFIX=$GITHUB_WORKSPACE/stubby-build -DBUILD_STUBBY=ON -DENABLE_STUB_ONLY=ON \
  -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release \
  -DOPENSSL_ROOT_DIR=$DEPS_DIR/openssl -DOPENSSL_INCLUDE_DIR=$DEPS_DIR/openssl/include \
  -DOPENSSL_CRYPTO_LIBRARY=$DEPS_DIR/openssl/lib/libcrypto.a \
  -DOPENSSL_SSL_LIBRARY=$DEPS_DIR/openssl/lib/libssl.a \
  -DYAML_LIBRARY=$DEPS_DIR/yaml/lib/libyaml.a -DYAML_INCLUDE_DIR=$DEPS_DIR/yaml/include \
  -DUSE_LIBIDN2=OFF \
  -DHAVE_DSA_SIG_SET0=1 -DHAVE_DSA_SET0_PQG=1 -DHAVE_DSA_SET0_KEY=1 \
  -DHAVE_RSA_SET0_KEY=1 -DHAVE_EVP_MD_CTX_NEW=1 -DHAVE_EVP_DIGESTVERIFY=1 \
  -DHAVE_HMAC_CTX_NEW=1 -DHAVE_OPENSSL_VERSION_NUM=1 -DHAVE_OPENSSL_VERSION=1 \
  -DHAVE_SSL_CTX_SET_CIPHERSUITES=1 -DHAVE_SSL_SET_CIPHERSUITES=1 \
  -DCMAKE_EXE_LINKER_FLAGS="-fPIE -pie -ldl $GITHUB_WORKSPACE/libbsd_signal_stub.a" \
  -DCMAKE_FIND_ROOT_PATH="$DEPS_DIR/openssl;$DEPS_DIR/yaml"
make -j$(nproc)
make install
$STRIP $GITHUB_WORKSPACE/stubby-build/bin/stubby
cp $GITHUB_WORKSPACE/stubby-build/bin/stubby "$GITHUB_WORKSPACE/artifacts/"
