# tester

CI/CD workflows to build [Termux EDL](https://github.com/Haris131/termux-edl) as a static PyInstaller binary and distribute as `.deb` packages.

## How it works

- `.github/workflows/build-termux-edl.yml` — GitHub Actions workflow
- `build-inside-termux.sh` — build script running inside `termux/termux-docker` via QEMU

On every push to `termux-edl` branch, the workflow:

1. Checks out this repo and `Haris131/termux-edl` (with Loaders submodule)
2. Sets up QEMU binfmt for `aarch64` and `arm` emulation
3. Runs the build script inside `termux-docker` for both architectures
4. Installs Python dependencies (`pyusb`, `pyserial`, `pycryptodome`, `Exscript`, etc.)
5. Clones `bkerler/Loaders` and patches `loader_db.py` to search `sys._MEIPASS/Loaders`
6. Builds a static `edl` binary with PyInstaller (`--onefile`)
7. Packages it as a `.deb` (binary only, no postinst — Loaders are embedded)
8. Creates an automatic GitHub release with tag `v3.62-build<run_number>`

## Artifacts

- `dist/edl` — standalone static binary
- `debs/termux-edl_3.62_<arch>.deb` — Termux `.deb` package (depends: `termux-api`)
