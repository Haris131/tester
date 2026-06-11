#!/bin/bash

cd "$GITHUB_WORKSPACE"
wget -q "https://ftp.gnu.org/gnu/bash/bash-${BASH_VERSION}.tar.gz"
tar xzf "bash-${BASH_VERSION}.tar.gz"
cd "bash-${BASH_VERSION}"
export ac_cv_func_dprintf=yes
export ac_cv_func_mkfifo=yes
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --disable-shared --enable-static --without-bash-malloc \
  --disable-readline --disable-history --disable-progcomp --disable-nls
sed -i '/extern void dprintf/d' externs.h
cat > mb-stub.c << 'MBEOF'
#include <stddef.h>
#include <wchar.h>
#include <string.h>
static mbstate_t _mbst;
int mblen(const char *s, size_t n) { if (s == NULL) { memset(&_mbst, 0, sizeof(_mbst)); return 0; } return mbrlen(s, n, &_mbst); }
int mbtowc(wchar_t *pwc, const char *s, size_t n) { if (s == NULL) { memset(&_mbst, 0, sizeof(_mbst)); return 0; } size_t r = mbrtowc(pwc, s, n, &_mbst); return (r == (size_t)-1 || r == (size_t)-2) ? -1 : (int)r; }
int wctomb(char *s, wchar_t wc) { if (s == NULL) { memset(&_mbst, 0, sizeof(_mbst)); return 0; } size_t r = wcrtomb(s, wc, &_mbst); return (r == (size_t)-1) ? -1 : (int)r; }
size_t mbstowcs(wchar_t *pwcs, const char *s, size_t n) { mbstate_t st = _mbst; return mbsrtowcs(pwcs, (const char **)&s, n, &st); }
size_t wcstombs(char *s, const wchar_t *pwcs, size_t n) { mbstate_t st = _mbst; return wcsrtombs(s, (const wchar_t **)&pwcs, n, &st); }
MBEOF
$CC $CFLAGS -c -o mb-stub.o mb-stub.c
make -j$(nproc) LDFLAGS+=" mb-stub.o"
$STRIP bash
cp bash "$GITHUB_WORKSPACE/artifacts/"
