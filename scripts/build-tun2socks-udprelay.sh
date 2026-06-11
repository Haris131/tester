#!/bin/bash
set -e
cd "$GITHUB_WORKSPACE"
git clone --depth=1 https://github.com/FH0/badvpn.git badvpn-udprelay
cd badvpn-udprelay
mkdir -p jni
sed 's|LOCAL_PATH := \$(call my-dir)|LOCAL_PATH := $(call my-dir)/..|' Android.mk > jni/Android.mk
cp Application.mk jni/
$NDK_ROOT/ndk-build NDK_PROJECT_PATH=. APP_ABI=$ABI APP_PLATFORM=android-$API
find obj -name "tun2socks" -type f -exec $STRIP {} \; -exec mv {} "$GITHUB_WORKSPACE/artifacts/badvpn-tun2socks-udprelay" \;
