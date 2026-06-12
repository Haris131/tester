#!/bin/bash

set -e
cd "$GITHUB_WORKSPACE"
git clone --depth=1 https://github.com/v2fly/v2ray-core.git
cd v2ray-core
GOARCH="$GOARCH" GOARM="$GOARM" CGO_ENABLED=0 GOOS=android \
  go build -ldflags="-w -s" -o "$GITHUB_WORKSPACE/artifacts/v2ray" ./main
