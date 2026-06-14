#!/bin/bash

cd "$GITHUB_WORKSPACE"
curl -fSL -o "openssh-${SSH_VERSION}.tar.gz" https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${SSH_VERSION}.tar.gz || \
curl -fSL -o "openssh-${SSH_VERSION}.tar.gz" https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${SSH_VERSION}.tar.gz || \
curl -fSL -o "openssh-${SSH_VERSION}.tar.gz" https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${SSH_VERSION}.tar.gz
tar xzf "openssh-${SSH_VERSION}.tar.gz"
cd "openssh-${SSH_VERSION}"

# getrrsetbyname stub for Android
cat > openbsd-compat/getrrsetbyname.c << 'FEOF'
#include "includes.h"
#if !defined(HAVE_GETRRSETBYNAME) && !defined(HAVE_LDNS)
#include "getrrsetbyname.h"
int getrrsetbyname(const char *hostname, unsigned int rdclass, unsigned int rdtype, unsigned int flags, struct rrsetinfo **res) { return ERRSET_FAIL; }
void freerrset(struct rrsetinfo *rrset) { (void)rrset; }
#endif
FEOF

# Fix bzero redeclaration for clang
sed -i 's|^bzero(void \*b, size_t n)|#ifdef bzero\n#undef bzero\n#endif\nbzero(void *b, size_t n)|' openbsd-compat/bsd-misc.c

# getifaddrs stub for Android API < 24 (OpenSSH 9.9p1 removed compat fallback)
# Must compile before configure so LDFLAGS is baked into Makefile
cat > bsd-getifaddrs.c << 'FEOF'
#if defined(__ANDROID_API__) && __ANDROID_API__ < 24
#include <errno.h>
struct ifaddrs {
    struct ifaddrs *ifa_next;
    char *ifa_name;
    unsigned int ifa_flags;
    struct sockaddr *ifa_addr;
    struct sockaddr *ifa_netmask;
    struct sockaddr *ifa_dstaddr;
    void *ifa_data;
};
int getifaddrs(struct ifaddrs **ifap) { *ifap = 0; errno = ENOSYS; return -1; }
void freeifaddrs(struct ifaddrs *ifa) { (void)ifa; }
#endif
FEOF
$CC $CFLAGS -c bsd-getifaddrs.c -o bsd-getifaddrs.o

export CFLAGS="$CFLAGS -I$DEPS_DIR/zlib/include -I$DEPS_DIR/openssl/include"
export LDFLAGS="$LDFLAGS -L$DEPS_DIR/zlib/lib -L$DEPS_DIR/openssl/lib $PWD/bsd-getifaddrs.o"

CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  ac_cv_func_getaddrinfo=yes ac_cv_have_int64_t=yes ac_cv_have_u_int64_t=yes ac_cv_have_uint64_t=yes \
  ac_cv_func_getpwnam_r=yes ac_cv_func_getpwuid_r=yes ac_cv_func_getgrgid_r=yes ac_cv_func_getgrnam_r=yes \
  ac_cv_func_clock_gettime=yes ac_cv_func_mmap=yes ac_cv_func_strnlen=yes ac_cv_func_va_copy=yes \
  ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes ac_cv_func_mblen=yes \
  ac_cv_func_getpagesize=yes ac_cv_c___attribute__=yes ac_cv_func_getifaddrs=no \
  ./configure --host="$HOST" --with-zlib="$DEPS_DIR/zlib" --with-ssl-dir="$DEPS_DIR/openssl" \
  --disable-strip --disable-etc-default-login --disable-lastlog --disable-utmp --disable-utmpx \
  --disable-wtmp --disable-wtmpx --disable-pututline --disable-pututxline --disable-pkcs11 \
  --with-ipaddr-display=none

# Remove retpolineplt (unsupported on Android API 33+), add gc-sections
sed -i 's/-Wl,-z,retpolineplt//g' Makefile
sed -i 's/^LDFLAGS=/& -Wl,--gc-sections /' Makefile

# Build only client binaries (not sshd which needs extra defines)
make -j$(nproc) ssh ssh-keygen ssh-keyscan ssh-keysign scp sftp
for f in ssh scp sftp ssh-keygen ssh-keyscan ssh-keysign; do
  [ -f "$f" ] && $STRIP "$f" && cp "$f" "$GITHUB_WORKSPACE/artifacts/"
done
