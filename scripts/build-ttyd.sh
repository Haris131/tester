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

# libuv does NOT use autoconf to detect preadv/pwritev — it has a hardcoded
# platform #if in src/unix/fs.c. Android isn't in that list, so preadv/pwritev
# are called directly even when unavailable (API < 24). Fix: add Android API
# level check to the existing fallback macro condition.
sed -i '/^#if defined(__CYGWIN__)/a\    (defined(__ANDROID__) \&\& __ANDROID_API__ < 24) || \\' \
  src/unix/fs.c

# For Android API < 21: inotify_init1 and pipe2 are not available.
# libuv uses them directly (inotify_init1 in linux.c, pipe2 in pipe.c)
# with no autoconf guards. Patch source as needed.
if [ "$API" -lt 21 ]; then
  # Replace inotify_init1 with inotify_init + fcntl
  sed -i 's/fd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);/fd = inotify_init();/' src/unix/linux.c
  sed -i '/^  fd = inotify_init();$/a\  if (fd >= 0) {\n    (void)fcntl(fd, F_SETFL, O_NONBLOCK);\n    (void)fcntl(fd, F_SETFD, FD_CLOEXEC);\n  }' src/unix/linux.c

  # Replace pipe2 with pipe + uv__cloexec + uv__nonblock (same pattern as #else branch)
  sed -i 's/#if defined(__FreeBSD__) || defined(__linux__)/#if defined(__FreeBSD__) || (defined(__linux__) \&\& !(defined(__ANDROID__) \&\& __ANDROID_API__ < 21))/' src/unix/pipe.c
fi

./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --prefix="$DEPS_DIR/libuv" --disable-shared --enable-static
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

# libuv compat for Android API < 21: provide epoll_create1, epoll_pwait, sendmmsg, recvmmsg
if [ "$API" -lt 21 ]; then
  cat > libuv_compat_19.c << 'COMPAT19'
#if defined(__ANDROID__) && __ANDROID_API__ < 21
#include <sys/socket.h>
#include <sys/epoll.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#ifndef EPOLL_CLOEXEC
#define EPOLL_CLOEXEC 02000000
#endif

#ifndef HAVE_STRUCT_MMSGHDR
struct mmsghdr {
  struct msghdr msg_hdr;
  unsigned int msg_len;
};
#endif

int epoll_create1(int flags) {
  int fd = epoll_create(1);
  if (fd < 0) return -1;
  if (flags & EPOLL_CLOEXEC) fcntl(fd, F_SETFD, FD_CLOEXEC);
  return fd;
}

int epoll_pwait(int epfd, struct epoll_event *events, int maxevents, int timeout, const sigset_t *sigmask) {
  (void)sigmask;
  return epoll_wait(epfd, events, maxevents, timeout);
}

int sendmmsg(int sockfd, struct mmsghdr *msgvec, unsigned int vlen, unsigned int flags) {
  int sent;
  for (sent = 0; sent < (int)vlen; sent++) {
    int ret = sendmsg(sockfd, &msgvec[sent].msg_hdr, flags);
    if (ret >= 0) { msgvec[sent].msg_len = ret; }
    else if (sent == 0) return -1;
    else break;
  }
  return sent;
}

int recvmmsg(int sockfd, struct mmsghdr *msgvec, unsigned int vlen, unsigned int flags, struct timespec *timeout) {
  (void)timeout;
  int received;
  for (received = 0; received < (int)vlen; received++) {
    int ret = recvmsg(sockfd, &msgvec[received].msg_hdr, flags);
    if (ret >= 0) { msgvec[received].msg_len = ret; }
    else if (received == 0) return -1;
    else break;
  }
  return received;
}
#endif
COMPAT19
  $CC -c -fPIC libuv_compat_19.c -o libuv_compat_19.o
  $AR rcs libuv_compat_19.a libuv_compat_19.o
fi

# ttyd
git clone --depth=1 https://github.com/tsl0922/ttyd.git
cd ttyd

# Link libuv compat library for API < 21
if [ "$API" -lt 21 ]; then
  sed -i 's|set(LINK_LIBS ${ZLIB_LIBRARIES} ${LIBWEBSOCKETS_LIBRARIES} ${JSON-C_LIBRARIES} ${LIBUV_LIBRARIES})|set(LINK_LIBS ${ZLIB_LIBRARIES} ${LIBWEBSOCKETS_LIBRARIES} ${JSON-C_LIBRARIES} ${LIBUV_LIBRARIES} ${CMAKE_SOURCE_DIR}/../libuv_compat_19.a)|' CMakeLists.txt
fi

# forkpty requires Android API 23+. Provide compat via openpty()+fork() for older API levels.
if [ "$API" -lt 23 ]; then
  cat > src/forkpty_compat.c << 'COMPATEOF'
#include <sys/ioctl.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

/* Android NDK r23b: openpty and forkpty both require API 23+.
   Provide both via direct /dev/ptmx access for API < 23. */
#if defined(__ANDROID__) && __ANDROID_API__ < 23
static int compat_openpty(int *amaster, int *aslave, char *name,
                           const struct termios *termp, const struct winsize *winp) {
  int master, slave;
  char *pts_name;
  master = open("/dev/ptmx", O_RDWR);
  if (master < 0) return -1;
  if (grantpt(master) || unlockpt(master)) { close(master); return -1; }
  pts_name = ptsname(master);
  if (!pts_name) { close(master); return -1; }
  slave = open(pts_name, O_RDWR);
  if (slave < 0) { close(master); return -1; }
  if (termp) tcsetattr(slave, TCSAFLUSH, termp);
  if (winp) ioctl(slave, TIOCSWINSZ, winp);
  *amaster = master;
  *aslave = slave;
  if (name) strcpy(name, pts_name);
  return 0;
}
#else
#include <pty.h>
#endif

pid_t forkpty(int *amaster, char *name, const struct termios *termp, const struct winsize *winp) {
  int master, slave;
#if defined(__ANDROID__) && __ANDROID_API__ < 23
  if (compat_openpty(&master, &slave, name, termp, winp) == -1)
#else
  if (openpty(&master, &slave, name, termp, winp) == -1)
#endif
    return -1;
  pid_t pid = fork();
  if (pid == -1) {
    close(master);
    close(slave);
    return -1;
  }
  if (pid == 0) {
    close(master);
    setsid();
    if (ioctl(slave, TIOCSCTTY, 0) == -1) _exit(1);
    dup2(slave, 0);
    dup2(slave, 1);
    dup2(slave, 2);
    if (slave > 2) close(slave);
    return 0;
  }
  close(slave);
  *amaster = master;
  return pid;
}
COMPATEOF
  sed -i '/^set(SOURCE_FILES/s/)$/ src\/forkpty_compat.c)/' CMakeLists.txt
fi

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
