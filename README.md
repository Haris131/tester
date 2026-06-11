# Libernet for Android

Cross-compiled networking tools for Android via GitHub Actions.

## Tools

| Tool | Description |
|------|-------------|
| [sshpass](https://sourceforge.net/projects/sshpass/) | Non-interactive SSH password auth |
| [badvpn-tun2socks](https://github.com/ambrop72/badvpn) | Tunnel TCP over SOCKS |
| [jq](https://jqlang.github.io/jq/) | Command-line JSON processor |
| [curl](https://curl.se/) | HTTP/FTP/etc data transfer tool |
| [httping](https://github.com/folkertvanheusden/httping) | HTTP ping utility |
| [bash](https://www.gnu.org/software/bash/) | GNU Bourne Again SHell |
| [dnstt-client](https://github.com/Haris131/dnstt) | DNS tunnel client |
| [go-tcp-proxy-tunnel](https://github.com/lutfailham96/go-tcp-proxy-tunnel) | TCP proxy tunnel |
| [OpenSSH client](https://www.openssh.com/) | SSH, scp, sftp, ssh-keygen, ssh-keyscan |
| [corkscrew](http://corkscrew.agroman.net/) | SSH over HTTP proxy |
| [stunnel](https://www.stunnel.org/) | TLS/SSL tunneling |
| [stubby](https://getdnsapi.net/) | DNS-over-TLS forwarder (getdns) |
| [php8](https://www.php.net/) | PHP CLI (experimental) |
| [python3](https://www.python.org/) | Python 3 interpreter (experimental) |
| [badvpn-tun2socks-udprelay](https://github.com/FH0/badvpn) | badvpn fork with UDP relay |

## Build Matrix

| API (Android) | Arch | OpenSSL |
|---------------|------|---------|
| 19 (4.4) | armv7a | 1.1.1w |
| 21 (5.0) | armv7a, aarch64 | 1.1.1w |
| 24 (7.0) | armv7a, aarch64 | 3.6.3 |

## Usage

Download the tarball from Actions, extract, and run on your device.
