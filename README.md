# XO-1 i586 curl + Sugar Browse (GTK2)

Dynamically linked libraries for OLPC XO-1 (**Geode / i586**), **curl**, and **Sugar Browse** (GTK2 / XULRunner). No GTK3. No Firefox deliverable.

## Artifacts (repo root)
| File | Notes |
|------|--------|
| `xo-openssl-curl-xo1-i586.tar.gz` | OpenSSL 1.1.1w + curl 7.88.1; max GLIBC_2.7 |
| `xo-gtk2-xo1-i586-glibc212.tar.gz` | `libgtk-x11-2.0.so.0` + deps; max GLIBC_2.4 |
| `xo-xulrunner-1.9.2-geode-i586.tar.gz` | FC14 xulrunner for Browse |
| `install.sh` | Deploy script |
| `download-xo1.sh` | Fetch all artifacts from GitHub on a bare XO-1 |

## Download on XO-1 (system curl broken)

GitHub serves files only over HTTPS. On XO-1 the stock **curl** often fails TLS handshake or is missing entirely. **wget** is usually present and accepts `--no-check-certificate` (TLS verify disabled — use only on a trusted network).

### One-shot (recommended)

```sh
wget --no-check-certificate -O download-xo1.sh \
  https://raw.githubusercontent.com/kenneyhe2/olpc/main/download-xo1.sh
chmod +x download-xo1.sh
sudo ./download-xo1.sh
cd /tmp/olpc-fetch && sudo ./install.sh
```

`download-xo1.sh` does two phases:

1. **Bootstrap** — `wget --no-check-certificate` fetches only `xo-openssl-curl-xo1-i586.tar.gz` (~4.8 MB), extracts it to `/opt/xo1-tls`.
2. **Fetch rest** — `/opt/xo1-tls/bin/curl` (with bundled OpenSSL 1.1.1w) downloads gtk2, xulrunner, and `install.sh`.

### Manual bootstrap (step by step)

If you prefer to type commands yourself:

```sh
REPO=https://raw.githubusercontent.com/kenneyhe2/olpc/main
mkdir -p ~/olpc && cd ~/olpc

# Step 1: curl tarball only (wget, TLS verify off)
wget --no-check-certificate -O xo-openssl-curl-xo1-i586.tar.gz \
  "$REPO/xo-openssl-curl-xo1-i586.tar.gz"

# Step 2: install bundled curl + OpenSSL
sudo tar -C / -xzf xo-openssl-curl-xo1-i586.tar.gz
/opt/xo1-tls/bin/curl -V    # needs LD_LIBRARY_PATH; see below

# Step 3: download remaining artifacts with bundled curl
export LD_LIBRARY_PATH=/opt/xo1-tls/lib
/opt/xo1-tls/bin/curl -fSL -o xo-gtk2-xo1-i586-glibc212.tar.gz \
  "$REPO/xo-gtk2-xo1-i586-glibc212.tar.gz"
/opt/xo1-tls/bin/curl -fSL -o xo-xulrunner-1.9.2-geode-i586.tar.gz \
  "$REPO/xo-xulrunner-1.9.2-geode-i586.tar.gz"
/opt/xo1-tls/bin/curl -fSL -o install.sh "$REPO/install.sh"
chmod +x install.sh
```

### Verify checksums (optional)

| File | MD5 |
|------|-----|
| `xo-openssl-curl-xo1-i586.tar.gz` | `ae2950be7950f33fee5adc4fdc50adf9` |
| `xo-gtk2-xo1-i586-glibc212.tar.gz` | `414c040cdd79322f229ff086acbbeb0a` |
| `xo-xulrunner-1.9.2-geode-i586.tar.gz` | `9a9bf96ced17b919585504aa09707193` |
| `install.sh` | `b65e79902d10a63f0d5fdf0760c41b8c` |

On XO-1: `md5sum <file>` (or `openssl md5 <file>`).

## Deploy on XO-1
Copy the `xo-*.tar.gz` files and `install.sh` to the XO (or use `download-xo1.sh` above), then:

```sh
chmod +x install.sh
sudo ./install.sh
/opt/xo1-tls/bin/curl -V
/opt/xo1-tls/bin/curl -I https://example.com
. /opt/xo1-tls/bin/xo1-env.sh
/opt/xo1-tls/bin/xo1-browse
```

## Host
Hyper-V platform (`vmms`); Docker Desktop here uses a WSL2 Linux VM on that platform. Long builds polled every 3 minutes.
