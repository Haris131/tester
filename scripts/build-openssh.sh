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

# Add gc-sections, disable retpolineplt, use noseparate-code + max-page-size=0x4000
# to match Termux's LOAD layout (3 segments instead of 4, 16K page alignment).
# Use recursive sed to handle various Makefile formats from configure.
sed -i '/^LDFLAGS[[:space:]]*=/ s/$/ -Wl,--gc-sections -Wl,-z,noretpolineplt -Wl,-z,noseparate-code -Wl,-z,max-page-size=0x4000/' Makefile

# Build only client binaries (not sshd which needs extra defines)
make -j$(nproc) ssh ssh-keygen ssh-keyscan ssh-keysign scp sftp

# Post-process: remove .preinit_array/.init_array/.fini_array which carry
# NDK CRT sentinel values that can crash on newer Android (14+).
# Must also zero out corresponding DT_* entries in .dynamic.
cleanup_binary() {
  local f="$1"
  [ ! -f "$f" ] && return

  # Remove the actual sections
  $OBJCOPY --remove-section=.preinit_array --remove-section=.init_array --remove-section=.fini_array "$f" 2>/dev/null || true

  # Zero out DT_PREINIT/INIT/FINI_ARRAYSZ in the dynamic section.
  # Setting SZ to 0 tells the linker there are no entries, so it won't
  # chase the (now-removed) section pointers. We ONLY zero d_val, NOT
  # d_tag — setting d_tag=0 (DT_NULL) mid-array would stop linker parsing.
  python3 -c "
import struct, sys
with open('$f', 'r+b') as fh:
    ident = fh.read(16)
    is_64 = ident[4] == 2
    if is_64:
        fh.seek(32)
        e_phoff, = struct.unpack('<Q', fh.read(8))
        phdr_size = 56
    else:
        fh.seek(28)
        e_phoff, = struct.unpack('<I', fh.read(4))
        phdr_size = 32
    # SZ tags: PREINIT_ARRAYSZ=33, INIT_ARRAYSZ=27, FINI_ARRAYSZ=28
    sz_tags = {33, 27, 28}
    # Address tags: PREINIT_ARRAY=32, INIT_ARRAY=25, FINI_ARRAY=26
    addr_tags = {32, 25, 26}
    # Find PT_DYNAMIC via program headers
    for i in range(100):
        fh.seek(e_phoff + i * phdr_size)
        phdr = fh.read(phdr_size)
        if not phdr or len(phdr) < phdr_size:
            break
        if is_64:
            p_type, p_flags, p_offset = struct.unpack('<IIQ', phdr[:16])
        else:
            p_type, p_offset, p_vaddr, p_filesz = struct.unpack('<IIII', phdr[:16])
        if p_type != 2:
            continue
        fh.seek(p_offset)
        entry_size = 16 if is_64 else 8
        for _ in range(256):
            data = fh.read(entry_size)
            if len(data) < entry_size:
                break
            tag, val = struct.unpack('<QQ' if is_64 else '<II', data)
            if tag == 0:
                break
            if tag in sz_tags or tag in addr_tags:
                fh.seek(-entry_size, 1)
                fh.write(b'\\x00' * entry_size)
                fh.seek(p_offset + (_ + 1) * entry_size)
        break
" 2>&1 | grep -v "^$" || true

  $STRIP "$f"
  cp "$f" "$GITHUB_WORKSPACE/artifacts/"
}

for f in ssh scp sftp ssh-keygen ssh-keyscan ssh-keysign; do
  cleanup_binary "$f"
done
