#!/bin/bash

set -e
cd "$GITHUB_WORKSPACE"
git clone --depth=1 https://github.com/librespeed/speedtest-go.git
cd speedtest-go
GOARCH="$GOARCH" GOARM="$GOARM" CGO_ENABLED=1 GOOS=android CC="$CC" \
  go build -ldflags="-w -s" -o "$GITHUB_WORKSPACE/artifacts/speedtest-go"
