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
apt-get install -y libusb python clang binutils make libxml2 libxslt rust cmake file termux-elf-cleaner patchelf git ccache 2>&1 || { echo "FAIL: apt-get install"; exit 1; }

echo "=== Setting up ccache ==="
export CCACHE_DIR="$TMPDIR/ccache"
export PATH="/usr/lib/ccache:$PATH"
ccache --max-size 1G 2>&1 || true
mkdir -p "$CCACHE_DIR"

echo "=== Installing Python build tools ==="
python3 -m pip install --upgrade pip wheel setuptools 2>&1

echo "=== Installing edl Python dependencies ==="
python3 -m pip install pyusb pyserial docopt pycryptodome pycryptodomex colorama \
            capstone qrcode requests \
            passlib lxml 2>&1
python3 -m pip install Exscript --no-deps 2>&1

export TMPDIR="$PREFIX/tmp"

# Create ldd wrapper if missing (not provided by binutils on Termux)
if ! command -v ldd &>/dev/null; then
  cat > "$PREFIX/bin/ldd" << 'LDDEOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-elf-cleaner --show-info "$@"
LDDEOF
  chmod +x "$PREFIX/bin/ldd"
fi

# keystone-engine needs a CMakeLists.txt patch for cmake >= 4.x
echo "=== Installing keystone-engine (patched for cmake 4.x) ==="
python3 -m pip download keystone-engine --no-deps --no-binary :all: -d "$TMPDIR/keystone-src" 2>&1
cd "$TMPDIR/keystone-src"
tar xzf keystone-engine-*.tar.gz
SRC_DIR=$(find . -maxdepth 1 -type d -name "keystone-engine*" | head -1)
cd "$SRC_DIR"
find . -name CMakeLists.txt -exec sed -i 's/cmake_minimum_required(VERSION [0-9.]*)/cmake_minimum_required(VERSION 3.5)/' {} +
find . -name CMakeLists.txt -exec sed -i '/cmake_policy(SET CMP0051 OLD)/d' {} +
python3 -m pip install . 2>&1
cd /workspace

echo "=== Installing PyInstaller ==="
python3 -m pip install pyinstaller 2>&1

echo "=== Installing edl ==="
mkdir -p "$TMPDIR/build-edl"
cp -a /workspace/edl-src/. "$TMPDIR/build-edl/"
cd "$TMPDIR/build-edl"

echo "=== Cloning bkerler/Loaders to share directory ==="
mkdir -p "$PREFIX/share/termux-edl"
rm -rf "$PREFIX/share/termux-edl/Loaders"
git clone --depth 1 https://github.com/bkerler/Loaders "$PREFIX/share/termux-edl/Loaders" 2>&1
rm -rf "$PREFIX/share/termux-edl/Loaders/.git"

echo "=== Patching loader_db.py to search sys._MEIPASS/Loaders ==="
python3 << 'PATCHEOF'
import os
filepath = "edlclient/Library/loader_db.py"
with open(filepath) as f:
    code = f.read()
old = (
    '    def init_loader_db(self):\n'
    '        for (dirpath, dirnames, filenames) in os.walk(os.path.join(parent_dir, "..", "Loaders")):\n'
    '            for filename in filenames:\n'
    '                fn = os.path.join(dirpath, filename)\n'
    '                found = False\n'
    '                for ext in [".bin", ".mbn", ".elf"]:\n'
    '                    if ext in filename[-4:]:\n'
    '                        found = True\n'
    '                        break\n'
    '                if not found:\n'
    '                    continue\n'
    '                try:\n'
    '                    hwid = filename.split("_")[0].lower()\n'
    '                    msmid = hwid[:8]\n'
    '                    try:\n'
    '                        int(msmid, 16)\n'
    '                    except:\n'
    '                        continue\n'
    '                    devid = hwid[8:]\n'
    '                    if devid == \'\':\n'
    '                        continue\n'
    '                    if len(filename.split("_")) < 2:\n'
    '                        continue\n'
    '                    pkhash = filename.split("_")[1].lower()\n'
    '                    for msmid in self.convertmsmid(msmid):\n'
    '                        mhwid = msmid + devid\n'
    '                        mhwid = mhwid.lower()\n'
    '                        if mhwid not in self.loaderdb:\n'
    '                            self.loaderdb[mhwid] = {}\n'
    '                        if pkhash not in self.loaderdb[mhwid]:\n'
    '                            self.loaderdb[mhwid][pkhash] = fn\n'
    '                except Exception as e:  # pylint: disable=broad-except\n'
    '                    self.debug(f"Filename:{filename} => {str(e)}")\n'
    '                    continue\n'
    '        return self.loaderdb'
)
new = (
    '    def init_loader_db(self):\n'
    '        search_paths = []\n'
    '        try:\n'
    '            if getattr(sys, \'frozen\', False) and hasattr(sys, \'_MEIPASS\'):\n'
    '                p = os.path.join(sys._MEIPASS, "Loaders")\n'
    '                if os.path.isdir(p):\n'
    '                    search_paths.append(p)\n'
    '        except:\n'
    '            pass\n'
    '        try:\n'
    '            exe_dir = os.path.dirname(os.path.abspath(sys.executable))\n'
    '            p = os.path.normpath(os.path.join(exe_dir, "..", "share", "termux-edl", "Loaders"))\n'
    '            if os.path.isdir(p):\n'
    '                search_paths.append(p)\n'
    '        except:\n'
    '            pass\n'
    '        try:\n'
    '            prefix = os.environ.get("PREFIX", "/data/data/com.termux/files/usr")\n'
    '            p = os.path.join(prefix, "share", "termux-edl", "Loaders")\n'
    '            if os.path.isdir(p) and p not in search_paths:\n'
    '                search_paths.append(p)\n'
    '        except:\n'
    '            pass\n'
    '        p = os.path.join(parent_dir, "..", "Loaders")\n'
    '        if os.path.isdir(p):\n'
    '            search_paths.append(p)\n'
    '        p = os.path.join(os.getcwd(), "Loaders")\n'
    '        if os.path.isdir(p):\n'
    '            search_paths.append(p)\n'
    '        self.loaderdb = {}\n'
    '        for search_path in search_paths:\n'
    '            for (dirpath, dirnames, filenames) in os.walk(search_path):\n'
    '                for filename in filenames:\n'
    '                    fn = os.path.join(dirpath, filename)\n'
    '                    found = False\n'
    '                    for ext in [".bin", ".mbn", ".elf"]:\n'
    '                        if ext in filename[-4:]:\n'
    '                            found = True\n'
    '                            break\n'
    '                    if not found:\n'
    '                        continue\n'
    '                    try:\n'
    '                        hwid = filename.split("_")[0].lower()\n'
    '                        msmid = hwid[:8]\n'
    '                        try:\n'
    '                            int(msmid, 16)\n'
    '                        except:\n'
    '                            continue\n'
    '                        devid = hwid[8:]\n'
    '                        if devid == \'\':\n'
    '                            continue\n'
    '                        if len(filename.split("_")) < 2:\n'
    '                            continue\n'
    '                        pkhash = filename.split("_")[1].lower()\n'
    '                        for msmid in self.convertmsmid(msmid):\n'
    '                            mhwid = msmid + devid\n'
    '                            mhwid = mhwid.lower()\n'
    '                            if mhwid not in self.loaderdb:\n'
    '                                self.loaderdb[mhwid] = {}\n'
    '                            if pkhash not in self.loaderdb[mhwid]:\n'
    '                                self.loaderdb[mhwid][pkhash] = fn\n'
    '                    except Exception as e:\n'
    '                        self.debug(f"Filename:{filename} => {str(e)}")\n'
    '                        continue\n'
    '        return self.loaderdb'
)
if old not in code:
    print("ERROR: Could not find original init_loader_db code")
    sys.exit(1)
code = code.replace(old, new, 1)
with open(filepath, "w") as f:
    f.write(code)
print("Patched loader_db.py successfully")
PATCHEOF

python3 -m pip install --no-deps . 2>&1

echo "=== Building static binary with PyInstaller ==="
PREFIX="/data/data/com.termux/files/usr"

PYTHON_LIBS=$(ls "$PREFIX/lib/libpython3"*.so 2>/dev/null || true)
ADD_BINARY_ARGS=""
for f in $PYTHON_LIBS; do
  ADD_BINARY_ARGS="$ADD_BINARY_ARGS --add-binary $f:."
done
# libusb for pyusb ctypes
if [ -f "$PREFIX/lib/libusb-1.0.so" ]; then
  ADD_BINARY_ARGS="$ADD_BINARY_ARGS --add-binary $PREFIX/lib/libusb-1.0.so:."
fi

pyinstaller --onefile \
  --name edl \
  --distpath /workspace/dist \
  --workpath /workspace/build \
  --specpath /workspace/build \
  $ADD_BINARY_ARGS \
  --add-data "$PREFIX/share/termux-edl/Loaders:Loaders" \
  --hidden-import usb \
  --hidden-import serial \
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
