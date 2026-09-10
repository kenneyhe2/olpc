# XO-1 i586 curl + Sugar Browse (GTK2)

Dynamically linked libraries for OLPC XO-1 (**Geode / i586**), **curl**, and **Sugar Browse** (GTK2 / XULRunner). No GTK3. No Firefox deliverable.

## Quick start

1. **Windows** — fix SSH config (below), then `ssh xo1`
2. **XO-1** — bootstrap curl tarball with **plain HTTP wget** (no TLS on the XO)
3. **XO-1** — fetch remaining files with bundled curl, run `install.sh`

## Artifacts (repo root)

| File | Notes |
|------|--------|
| `xo-openssl-curl-xo1-i586-glibc212.tar.gz` | **Bootstrap first** — OpenSSL 1.1.1w + curl 7.88.1 (GLIBC 2.12 build) |
| `xo-openssl-curl-xo1-i586.tar.gz` | Same payload, alternate name on `main` |
| `xo-gtk2-xo1-i586-glibc212.tar.gz` | `libgtk-x11-2.0.so.0` + deps |
| `xo-xulrunner-1.9.2-geode-i586.tar.gz` | FC14 xulrunner for Browse |
| `install.sh` | Deploy script |
| `download-xo1.sh` | Fetch all artifacts on XO (uses HTTP proxy wget) |

---

## SSH from Windows (OpenSSH 9.x → XO-1 OpenSSH 5.5)

XO-1 runs **OpenSSH 5.5** (legacy `ssh-rsa` only for modern clients). Windows **OpenSSH 9.5+** disables that by default. XO-1 does **not** accept `ed25519` keys — use **RSA** for `authorized_keys`.

### Connect now (skip broken config)

If `ssh xo1` dies on config lines 10/12/13, your `C:\Users\citadelone\.ssh\config` is still wrong. OpenSSH reads it **before** `-o` flags. Bypass it:

```powershell
ssh -F NUL -o "HostKeyAlgorithms=+ssh-rsa" -o "PubkeyAcceptedAlgorithms=+ssh-rsa" -o "KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1" olpc@10.0.0.25
```

### Persistent SSH config

Create or edit `C:\Users\citadelone\.ssh\config` (or run `.\fix-ssh-config-windows.ps1` from this repo):

```sshconfig
Host xo1 olpc-xo1 10.0.0.25
    HostName 10.0.0.25
    User olpc
    IdentityFile ~/.ssh/id_rsa_olpc

    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    KexAlgorithms +diffie-hellman-group-exchange-sha256,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1
    Ciphers +aes128-ctr,aes256-ctr,aes128-cbc,aes256-cbc
    MACs +hmac-sha2-256,hmac-sha1
    StrictHostKeyChecking accept-new
```

**Rules for OpenSSH 9.5+ Windows:**

| Wrong | Correct |
|-------|---------|
| `HostKeyAlgorithms +ssh-rsa,+ssh-dss` | `HostKeyAlgorithms +ssh-rsa` (no `ssh-dss` — removed) |
| `KexAlgorithms +algo1,+algo2,+algo3` | `KexAlgorithms +algo1,algo2,algo3` (one `+` at start only) |
| `Ciphers +aes128-ctr,+aes256-ctr,...` | `Ciphers +aes128-ctr,aes256-ctr,...` |

Standalone config file: copy `ssh-config-xo1-only` to `%USERPROFILE%\.ssh\config-xo1`, then:

```powershell
ssh -F $env:USERPROFILE\.ssh\config-xo1 xo1
```

### RSA key (passwordless)

```powershell
ssh-keygen -t rsa -b 2048 -f $env:USERPROFILE\.ssh\id_rsa_olpc
type $env:USERPROFILE\.ssh\id_rsa_olpc.pub | ssh xo1 "mkdir -p .ssh && chmod 700 .ssh && cat >> .ssh/authorized_keys && chmod 600 .ssh/authorized_keys"
ssh xo1 whoami
```

---

## Download on XO-1 (no HTTPS — use HTTP wget)

Stock **curl** and **wget** on XO-1 often fail TLS (`unable to establish SSL connection`). Do **not** use `https://` URLs on the XO for the bootstrap step.

Use **plain HTTP** via [pkgforge](http://http.pkgforge.dev/) — it fetches the GitHub `raw` URL server-side and serves it over HTTP to the XO.

### Step 1 — bootstrap curl tarball (HTTP wget)

On the XO-1 terminal. Build the URL in **pieces** (avoids line-wrap / paste errors):

```sh
U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
U="$U/kenneyhe2/olpc/main/xo-openssl-curl-xo1-i586-glibc212.tar.gz"
echo "$U"
wget -O xo-openssl-curl-xo1-i586-glibc212.tar.gz "$U"
```

`echo` must print **one line** with **no spaces** in the middle of the path, e.g.:

```text
http://http.pkgforge.dev/https://raw.githubusercontent.com/kenneyhe2/olpc/main/xo-openssl-curl-xo1-i586-glibc212.tar.gz
```

Then extract:

```sh
sudo tar -C / -xzf xo-openssl-curl-xo1-i586-glibc212.tar.gz
export LD_LIBRARY_PATH=/opt/xo1-tls/lib
/opt/xo1-tls/bin/curl -V
```

### Step 2 — fetch remaining artifacts (bundled curl + HTTPS)

After bootstrap, `/opt/xo1-tls/bin/curl` has OpenSSL 1.1.1w and can use HTTPS:

```sh
REPO=https://raw.githubusercontent.com/kenneyhe2/olpc/main
mkdir -p ~/olpc && cd ~/olpc

/opt/xo1-tls/bin/curl -fSL -o xo-gtk2-xo1-i586-glibc212.tar.gz \
  "$REPO/xo-gtk2-xo1-i586-glibc212.tar.gz"
/opt/xo1-tls/bin/curl -fSL -o xo-xulrunner-1.9.2-geode-i586.tar.gz \
  "$REPO/xo-xulrunner-1.9.2-geode-i586.tar.gz"
/opt/xo1-tls/bin/curl -fSL -o install.sh "$REPO/install.sh"
chmod +x install.sh
```

Or fetch `download-xo1.sh` the same HTTP way, then run it (phase 1 skips if curl already installed):

```sh
U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
U="$U/kenneyhe2/olpc/main/download-xo1.sh"
echo "$U"
wget -O download-xo1.sh "$U"
chmod +x download-xo1.sh
sudo ./download-xo1.sh
```

### HTTP wget helper (any repo file)

```sh
pkgforge() {
  U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
  U="$U/kenneyhe2/olpc/main/$1"
  echo "$U"
  wget -O "$1" "$U"
}

pkgforge xo-openssl-curl-xo1-i586-glibc212.tar.gz
```

### Fallback — SCP from Windows

If HTTP wget also fails on the XO, download on Windows and `scp` after SSH works:

```powershell
$TGZ = "xo-openssl-curl-xo1-i586-glibc212.tar.gz"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/kenneyhe2/olpc/main/$TGZ" -OutFile $env:TEMP\$TGZ
scp $env:TEMP\$TGZ xo1:/tmp/
```

On XO: `sudo tar -C / -xzf /tmp/$TGZ` then continue at Step 2.

### Verify checksums (optional)

| File | MD5 |
|------|-----|
| `xo-openssl-curl-xo1-i586-glibc212.tar.gz` | `ae2950be7950f33fee5adc4fdc50adf9` |
| `xo-gtk2-xo1-i586-glibc212.tar.gz` | `414c040cdd79322f229ff086acbbeb0a` |
| `xo-xulrunner-1.9.2-geode-i586.tar.gz` | `9a9bf96ced17b919585504aa09707193` |
| `install.sh` | `b65e79902d10a63f0d5fdf0760c41b8c` |

On XO-1: `md5sum <file>`

---

## Deploy on XO-1

```sh
cd ~/olpc   # or /tmp/olpc-fetch after download-xo1.sh
sudo ./install.sh
/opt/xo1-tls/bin/curl -V
/opt/xo1-tls/bin/curl -I https://example.com
. /opt/xo1-tls/bin/xo1-env.sh
/opt/xo1-tls/bin/xo1-browse
```

## Automate from Windows (SSH + HTTP wget on XO)

```powershell
ssh xo1 @"
U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
U=\"\$U/kenneyhe2/olpc/main/download-xo1.sh\"
wget -O download-xo1.sh \"\$U\" && chmod +x download-xo1.sh && sudo ./download-xo1.sh
"@
```

## Host

Hyper-V platform (`vmms`); Docker Desktop here uses a WSL2 Linux VM on that platform.
