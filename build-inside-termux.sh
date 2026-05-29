#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# If running as root, drop privileges to UID 1000 (system) via su.
# This bypasses apt's compiled-in root check naturally.
# Note: don't use python3 here — it's not in the base bootstrap.
if [ "$(id -u)" = "0" ]; then
  echo "=== Dropping root privileges to UID 1000 ==="
  exec /system/bin/su system -s /data/data/com.termux/files/usr/bin/bash "$0"
  exit 1
fi

# Now running as UID 1000 (system user) — apt root check passes.

# Needed by maturin (rust/cryptography build)
export ANDROID_API_LEVEL=31
export CFLAGS="-Wno-register"
export CXXFLAGS="-Wno-register"

echo "=== Updating Termux packages ==="
apt-get update -y
apt-get --fix-broken install -y || true

echo "=== Adding tur-repo (for gcc-11) ==="
apt-get install -y tur-repo
apt-get update -y

echo "=== Installing system dependencies ==="
apt-get install -y libusb python clang binutils-is-llvm gcc-11 make libxml2 libxslt rust

echo "=== Installing Python build tools ==="
python3 -m pip install --upgrade pip wheel setuptools

echo "=== Installing edl Python dependencies ==="
python3 -m pip install pyusb pyserial docopt pycryptodome colorama \
            capstone keystone-engine qrcode requests \
            passlib Exscript lxml

echo "=== Installing PyInstaller ==="
python3 -m pip install pyinstaller

echo "=== Installing edl ==="
mkdir -p /tmp/build
cp -a /workspace/edl-src /tmp/build/edl
cd /tmp/build/edl

echo "=== Patching loader_db.py ==="
python3 /workspace/patch-loader.py

python3 -m pip install --no-deps .

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
  --hidden-import Exscript \
  --hidden-import lxml \
  --hidden-import lxml.etree \
  --hidden-import lxml.html \
  edl.py

echo "=== Done ==="
ls -lh /workspace/dist/edl
file /workspace/dist/edl
