#!/bin/bash

cd "$GITHUB_WORKSPACE"
wget -q "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-${JQ_VERSION}.tar.gz"
tar xzf "jq-${JQ_VERSION}.tar.gz"
cd "jq-${JQ_VERSION}"
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  --disable-docs --disable-maintainer-mode --disable-shared --enable-static --with-oniguruma=builtin
make -j$(nproc)
$STRIP jq
cp jq "$GITHUB_WORKSPACE/artifacts/"
