# XO-1 i586 curl + Sugar Browse (GTK2)

Dynamically linked libraries for OLPC XO-1 (**Geode / i586**), **curl**, and **Sugar Browse** (GTK2 / XULRunner). No GTK3. No Firefox deliverable.

## Artifacts (`out/`)
| File | Notes |
|------|--------|
| `xo-openssl-curl-xo1-i586.tar.gz` | OpenSSL 1.1.1w + curl 7.88.1; max GLIBC_2.7 |
| `xo-gtk2-xo1-i586-glibc212.tar.gz` | `libgtk-x11-2.0.so.0` + deps; max GLIBC_2.4 |
| `xo-xulrunner-1.9.2-geode-i586.tar.gz` | FC14 xulrunner for Browse |
| `install.sh` | Deploy script (also at repo root) |
| `EVIDENCE-*.txt` | Probes |

## Deploy on XO-1
Copy `out/*.tar.gz` and `install.sh` to the XO, then:

```sh
chmod +x install.sh
sudo ./install.sh
/opt/xo1-tls/bin/curl -V
/opt/xo1-tls/bin/curl -I https://example.com
. /opt/xo1-tls/bin/xo1-browse          # env only (safe to source)
/opt/xo1-tls/bin/xo1-browse            # launch Browse (Sugar session)
```

## Host
Hyper-V platform (`vmms`); Docker Desktop here uses a WSL2 Linux VM on that platform. Long builds polled every 3 minutes.
