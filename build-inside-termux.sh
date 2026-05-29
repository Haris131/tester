#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# termux-docker default entrypoint already runs as system user (UID 1000).
# apt root check is bypassed naturally.

echo "=== Debug: id=$(id) HOME=$HOME PREFIX=$PREFIX PATH=$PATH ==="

# Needed by maturin (rust/cryptography build via Exscript/paramiko)
export ANDROID_API_LEVEL=31
export CFLAGS="-Wno-register"
export CXXFLAGS="-Wno-register"

echo "=== Updating Termux packages ==="
apt-get update -y 2>&1 || { echo "FAIL: apt-get update"; exit 1; }

apt-get --fix-broken install -y 2>&1 || true

echo "=== Installing system dependencies ==="
apt-get install -y libusb python clang binutils make libxml2 libxslt rust cmake file termux-elf-cleaner 2>&1 || { echo "FAIL: apt-get install"; exit 1; }

echo "=== Installing Python build tools ==="
python3 -m pip install --upgrade pip wheel setuptools 2>&1

echo "=== Installing edl Python dependencies ==="
python3 -m pip install pyusb pyserial docopt pycryptodome pycryptodomex colorama \
            capstone qrcode requests \
            passlib lxml 2>&1

export TMPDIR="$PREFIX/tmp"

# keystone-engine needs a CMakeLists.txt patch for cmake >= 4.x
echo "=== Installing keystone-engine (patched for cmake 4.x) ==="
python3 -m pip download keystone-engine --no-deps --no-binary :all: -d "$TMPDIR/keystone-src" 2>&1
cd "$TMPDIR/keystone-src"
tar xzf keystone-engine-*.tar.gz
SRC_DIR=$(find . -maxdepth 1 -type d -name "keystone-engine*" | head -1)
cd "$SRC_DIR"
sed -i 's/cmake_minimum_required(VERSION [0-9.]*)/cmake_minimum_required(VERSION 3.5)/' src/CMakeLists.txt
python3 -m pip install . 2>&1
cd /workspace

echo "=== Installing PyInstaller ==="
python3 -m pip install pyinstaller 2>&1

echo "=== Installing edl ==="
mkdir -p "$TMPDIR/build-edl"
cp -a /workspace/edl-src/. "$TMPDIR/build-edl/"
cd "$TMPDIR/build-edl"

echo "=== Patching loader_db.py ==="
python3 /workspace/patch-loader.py 2>&1

python3 -m pip install --no-deps . 2>&1

echo "=== Building static binary with PyInstaller ==="
PREFIX="/data/data/com.termux/files/usr"

PYTHON_LIBS=$(ls "$PREFIX/lib/libpython3"*.so 2>/dev/null || true)
ADD_BINARY_ARGS=""
for f in $PYTHON_LIBS; do
  ADD_BINARY_ARGS="$ADD_BINARY_ARGS --add-binary $f:."
done

pyinstaller --onefile \
  --name edl \
  --distpath /workspace/dist \
  --workpath /workspace/build \
  --specpath /workspace \
  $ADD_BINARY_ARGS \
  --hidden-import pyusb \
  --hidden-import pyserial \
  --hidden-import docopt \
  --hidden-import Cryptodome \
  --hidden-import Cryptodome.Math \
  --hidden-import Cryptodome.Cipher \
  --hidden-import Cryptodome.Protocol \
  --hidden-import Cryptodome.Util \
  --hidden-import Cryptodome.Hash \
  --hidden-import colorama \
  --hidden-import capstone \
  --hidden-import keystone \
  --hidden-import qrcode \
  --hidden-import requests \
  --hidden-import passlib \
  --hidden-import lxml \
  --hidden-import lxml.etree \
  --hidden-import lxml.html \
  edl.py 2>&1

echo "=== Done ==="
ls -lh /workspace/dist/edl
file /workspace/dist/edl
