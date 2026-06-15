# Libernet for Android

Cross-compiled networking tools for Android via GitHub Actions.

## Tools

| Tool | Description | Works on |
|------|-------------|----------|
| [badvpn-tun2socks](https://github.com/ambrop72/badvpn) | Tunnel TCP over SOCKS | API 19+ (needs tun) |
| [badvpn-tun2socks-udprelay](https://github.com/FH0/badvpn) | badvpn fork with UDP relay | API 19+ (needs tun) |
| [bash](https://www.gnu.org/software/bash/) | GNU Bourne Again SHell | API 19+ |
| [ccminer](https://github.com/Darktron/ccminer) | CPU miner (Verus/Equihash) | API 24+ (arm64-v8a only, OpenMP statically linked) |
| [corkscrew](http://corkscrew.agroman.net/) | SSH over HTTP proxy | API 19+ |
| [curl](https://curl.se/) | HTTP/FTP/etc data transfer tool | API 19+ |
| [dnstt-client](https://github.com/Haris131/dnstt) | DNS tunnel client | API 19+ |
| [go-tcp-proxy-tunnel](https://github.com/lutfailham96/go-tcp-proxy-tunnel) | TCP proxy tunnel | API 19+ |
| [httping](https://github.com/folkertvanheusden/httping) | HTTP ping utility | API 19+ |
| [jq](https://jqlang.github.io/jq/) | Command-line JSON processor | API 19+ |
| [OpenSSH client](https://www.openssh.com/) | SSH, scp, sftp, ssh-keygen, ssh-keyscan | API 19+ |
| [openvpn](https://openvpn.net/) | Open-source VPN client | API 19+ (needs tun) |
| [php8](https://www.php.net/) | PHP CLI (curl, zip, phar, json, session, mbstring, iconv, posix, fileinfo, filter, ctype, bcmath, calendar, sockets, pcntl, openssl, zlib, dom, xml, simplexml, tokenizer, exif, sodium) | API 19+ |
| [speedtest-go](https://github.com/librespeed/speedtest-go) | Self-hosted speed test server | API 19+ |
| [sshpass](https://sourceforge.net/projects/sshpass/) | Non-interactive SSH password auth | API 19+ |
| [stubby](https://getdnsapi.net/) | DNS-over-TLS forwarder (getdns) | API 24+ |
| [stunnel](https://www.stunnel.org/) | TLS/SSL tunneling | API 19+ |
| [ttyd](https://github.com/tsl0922/ttyd) | Web terminal emulator | API 19+ |
| [v2ray-core](https://github.com/v2fly/v2ray-core) | Proxy platform (VMess, VLESS, Shadowsocks, etc.) | API 19+ |
| [vnstat](https://github.com/vergoh/vnstat) | Network traffic monitor | API 19+ |
| [vnstatd](https://github.com/vergoh/vnstat) | vnstat daemon | API 19+ |

## Compatibility Notes

| Tool | API 19 | API 21 | API 24 | Notes |
|------|--------|--------|--------|-------|
| badvpn-tun2socks | ✅ | ✅ | ✅ | Needs tun device |
| badvpn-tun2socks-udprelay | ✅ | ✅ | ✅ | Needs tun device |
| bash | ✅ | ✅ | ✅ | |
| ccminer | N/A | N/A | ✅ | arm64-v8a only; ARMv8 crypto extensions; NDK libomp.a requires API 24+ |
| corkscrew | ✅ | ✅ | ✅ | |
| curl | ✅ | ✅ | ✅ | |
| dnstt-client | ✅ | ✅ | ✅ | |
| go-tcp-proxy-tunnel | ✅ | ✅ | ✅ | |
| httping | ✅ | ✅ | ✅ | |
| jq | ✅ | ✅ | ✅ | |
| OpenSSH | ✅ | ✅ | ✅ | |
| openvpn | ✅ | ✅ | ✅ | Needs tun device (`--dev tun`) |
| php8 | ✅ | ✅ | ✅ | Uses compat stubs for mblen/localeconv/DNS; modules: curl, zip, phar, json, session, mbstring, iconv, posix, fileinfo, filter, ctype, bcmath, calendar, sockets, pcntl, openssl, zlib, dom, xml, simplexml, tokenizer, exif, sodium |
| speedtest-go | ✅ | ✅ | ✅ | Go binary with CGO |
| sshpass | ✅ | ✅ | ✅ | |
| stubby | ❌ | ❌ | ✅ | getdns needs API 24 (getifaddrs, res_nsearch) |
| stunnel | ✅ | ✅ | ✅ | |
| ttyd | ✅ | ✅ | ✅ | Uses PTY compat shim on API < 23 |
| v2ray-core | ✅ | ✅ | ✅ | Go binary with CGO |
| vnstat/vnstatd | ✅ | ✅ | ✅ | Requires writeable storage for DB |

### API 19 Specifics

- ttyd uses `forkpty` compat via `/dev/ptmx` (API < 23)
- libuv uses compat shims for: `epoll_create1`, `epoll_pwait`, `sendmmsg`, `recvmmsg`, `accept4`, `dup3`, `pthread_condattr_setclock`, `pthread_gettid_np`
- OpenSSH falls back to `/dev/urandom` for RNG, uses `getifaddrs` stub (returns ENOSYS — `BindInterface` won't work)
- stunnel falls back to OpenSSL RNG, no runtime issues
- php8 uses compat stubs for `mblen`, `getdtablesize`, `localeconv`, DNS functions
- **stubby** is the only tool **not available** on API 19 — getdns requires API 24 for `getifaddrs` and `res_nsearch`
- **ccminer** not available on API 19/21 — API 19 has no arm64 support; API 21 arm64 exists but NDK's `libomp.a` (OpenMP, now statically linked) targets API 24+

## Build Matrix

5 configurations across the matrix:

| Config | API | Arch | OpenSSL |
|--------|-----|------|---------|
| 1 | 19 (4.4) | armeabi-v7a | 1.1.1w |
| 2 | 21 (5.0) | armeabi-v7a | 1.1.1w |
| 3 | 21 (5.0) | arm64-v8a | 1.1.1w |
| 4 | 24 (7.0) | armeabi-v7a | 3.6.3 |
| 5 | 24 (7.0) | arm64-v8a | 3.6.3 |

All 5 configs build successfully with no `continue-on-error` on any step.  
`ccminer` only builds on arm64-v8a configs (3 and 5) — skipped on armeabi-v7a.  
Note: arm64 builds target API 24+ at runtime because NDK's statically-linked `libomp.a` requires API 24.

## Downloads

Pre-built binaries are available from:
- **GitHub Releases** — latest builds with all variants
- **Actions artifacts** — individual per-config tarballs

Download, extract, and run on your device.
