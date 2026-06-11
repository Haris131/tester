#!/bin/bash

cd "$GITHUB_WORKSPACE"
git clone --depth=1 https://github.com/lutfailham96/go-tcp-proxy-tunnel.git
cd go-tcp-proxy-tunnel
GOARCH="$GOARCH" GOARM="$GOARM" CGO_ENABLED=1 GOOS=android CC="$CC" \
  go build -ldflags="-w -s" -o "$GITHUB_WORKSPACE/artifacts/go-tcp-proxy-tunnel" ./cmd/tcp-proxy-tunnel/main.go
