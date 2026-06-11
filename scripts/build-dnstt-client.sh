#!/bin/bash

cd "$GITHUB_WORKSPACE"
git clone --depth=1 https://github.com/Haris131/dnstt.git
cd dnstt
GOARCH="$GOARCH" GOARM="$GOARM" CGO_ENABLED=1 GOOS=android CC="$CC" \
  go build -ldflags="-w -s" -o "$GITHUB_WORKSPACE/artifacts/dnstt-client" ./dnstt-client
