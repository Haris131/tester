#!/bin/bash

set -e
cd "$GITHUB_WORKSPACE"
TOOLCHAIN="$NDK_ROOT/build/cmake/android.toolchain.cmake"
[ -f "$TOOLCHAIN" ] || TOOLCHAIN="$NDK_ROOT/cmake/android.toolchain.cmake"

build_cmake_dep() {
  local name="$1" url="$2" srcdir="$3" prefix="$4" conf="$5"
  wget -q "$url" -O "${name}.tar.gz"
  tar xzf "${name}.tar.gz"
  cd "$srcdir"
  mkdir -p build && cd build
  cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="android-$API" \
    -DANDROID_STL=none -DCMAKE_C_FLAGS="$CFLAGS" \
    -DBUILD_SHARED_LIBS=OFF $conf
  make -j$(nproc)
  make install
  cd "$GITHUB_WORKSPACE"
}

# libuv (autotools, not cmake)
wget -q "https://dist.libuv.org/dist/v1.48.0/libuv-v1.48.0-dist.tar.gz"
tar xzf libuv-v1.48.0-dist.tar.gz
cd "$(tar tf libuv-v1.48.0-dist.tar.gz | head -1 | cut -d/ -f1)"
UV_EXTRA_CONF=
if [ "$API" -lt 21 ]; then
  UV_EXTRA_CONF="$UV_EXTRA_CONF ac_cv_func_inotify_init1=no ac_cv_func_pipe2=no"
fi
if [ "$API" -lt 24 ]; then
  UV_EXTRA_CONF="$UV_EXTRA_CONF ac_cv_func_preadv=no ac_cv_func_pwritev=no"
fi
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --prefix="$DEPS_DIR/libuv" --disable-shared --enable-static $UV_EXTRA_CONF
make -j$(nproc)
make install
cd "$GITHUB_WORKSPACE"

# json-c
build_cmake_dep json-c \
  "https://github.com/json-c/json-c/archive/refs/tags/json-c-0.17-20230812.tar.gz" \
  "json-c-json-c-0.17-20230812" \
  "$DEPS_DIR/json-c" \
  "-DDISABLE_THREAD_LOCAL_HANDLERS=ON -DENABLE_RDRAND=OFF"

# libwebsockets
build_cmake_dep libwebsockets \
  "https://github.com/warmcat/libwebsockets/archive/refs/tags/v4.3.3.tar.gz" \
  "libwebsockets-4.3.3" \
  "$DEPS_DIR/lws" \
  "-DLWS_WITH_SSL=OFF -DLWS_WITH_ZLIB=OFF -DLWS_WITH_CLIENT=ON -DLWS_WITHOUT_TESTAPPS=ON -DLWS_STATIC_PIC=ON -DLWS_WITH_SHARED=OFF -DLWS_WITH_LIBUV=ON -DCMAKE_FIND_ROOT_PATH=$DEPS_DIR/libuv"

# fix lws cmake config to not reference shared library target
sed -i '/set(LIBWEBSOCKETS_LIBRARIES/s/ websockets_shared)/)/' \
  "$DEPS_DIR/lws/lib/cmake/libwebsockets/libwebsockets-config.cmake"

# ttyd
git clone --depth=1 https://github.com/tsl0922/ttyd.git
cd ttyd
mkdir -p build && cd build
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="android-$API" \
  -DANDROID_STL=none -DCMAKE_C_FLAGS="$CFLAGS" \
  -DCMAKE_INSTALL_PREFIX="$DEPS_DIR/ttyd" \
  -DCMAKE_FIND_ROOT_PATH="$DEPS_DIR/libuv;$DEPS_DIR/json-c;$DEPS_DIR/lws" \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DBUILD_SHARED_LIBS=OFF
make -j$(nproc)
$STRIP ttyd || true
cp ttyd "$GITHUB_WORKSPACE/artifacts/"
