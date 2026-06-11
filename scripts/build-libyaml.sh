#!/bin/bash
set -e
cd "$GITHUB_WORKSPACE"
wget -q "https://github.com/yaml/libyaml/releases/download/${YAML_VERSION}/yaml-${YAML_VERSION}.tar.gz"
tar xzf "yaml-${YAML_VERSION}.tar.gz"
cd "yaml-${YAML_VERSION}"
./configure --host="$HOST" CC="$CC" CFLAGS="$CFLAGS" --prefix="$DEPS_DIR/yaml" --disable-shared --enable-static
make -j$(nproc)
make install
