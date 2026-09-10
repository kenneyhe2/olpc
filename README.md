# XO-1 i586 curl + Sugar Browse (GTK2)

Dynamically linked libraries for OLPC XO-1 (**Geode / i586**), **curl**, and **Sugar Browse** (GTK2 / XULRunner). No GTK3. No Firefox deliverable.

## Quick start

1. **Windows** — fix SSH config (below), then `ssh xo1`
2. **XO-1** — HTTP wget `install.sh`, run it (fetch + deploy in one script)

```sh
U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
U="$U/kenneyhe2/olpc/main/install.sh"
echo "$U"
wget -O install.sh "$U"
chmod +x install.sh
sudo ./install.sh
```

`echo` must print **one line** with **no spaces** in the middle of the path:

```text
http://http.pkgforge.dev/https://raw.githubusercontent.com/kenneyhe2/olpc/main/install.sh
```

## Artifacts (repo root)

| File | Notes |
|------|--------|
| `install.sh` | **One script** — HTTP wget bootstrap, fetch rest, extract to `/opt` |
| `xo-openssl-curl-xo1-i586-glibc212.tar.gz` | OpenSSL 1.1.1w + curl 7.88.1 (fetched by `install.sh`) |
| `xo-gtk2-xo1-i586-glibc212.tar.gz` | `libgtk-x11-2.0.so.0` + deps |
| `xo-xulrunner-1.9.2-geode-i586.tar.gz` | FC14 xulrunner for Browse |

`install.sh` does three phases automatically:

1. **HTTP wget** (pkgforge) — bootstrap `xo-openssl-curl-xo1-i586-glibc212.tar.gz` if needed
2. **Bundled curl** — fetch gtk2 + xulrunner tarballs over HTTPS
3. **Deploy** — extract all tarballs under `/opt`, write `xo1-env.sh` / `xo1-browse`

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

Standalone config: copy `ssh-config-xo1-only` to `%USERPROFILE%\.ssh\config-xo1`, then:

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

Stock **curl** and **wget** on XO-1 often fail TLS (`unable to establish SSL connection`). Do **not** use `https://` URLs on the XO for the first step.

Use **plain HTTP** via [pkgforge](http://http.pkgforge.dev/) — it fetches the GitHub `raw` URL server-side and serves it over HTTP to the XO.

### One command — fetch and install

```sh
U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
U="$U/kenneyhe2/olpc/main/install.sh"
echo "$U"
wget -O install.sh "$U"
chmod +x install.sh
sudo ./install.sh
```

### HTTP wget helper (any repo file)

Build URL in pieces, `echo` then `wget` (no `--no-check-certificate`):

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

If HTTP wget fails on the XO, copy tarballs from Windows after SSH works:

```powershell
$TGZ = "xo-openssl-curl-xo1-i586-glibc212.tar.gz"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/kenneyhe2/olpc/main/$TGZ" -OutFile $env:TEMP\$TGZ
scp $env:TEMP\$TGZ xo1:/tmp/
```

On XO: place tarballs next to `install.sh` and run `sudo ./install.sh` (skips fetch for files already present).

### Verify checksums (optional)

| File | MD5 |
|------|-----|
| `xo-openssl-curl-xo1-i586-glibc212.tar.gz` | `ae2950be7950f33fee5adc4fdc50adf9` |
| `xo-gtk2-xo1-i586-glibc212.tar.gz` | `414c040cdd79322f229ff086acbbeb0a` |
| `xo-xulrunner-1.9.2-geode-i586.tar.gz` | `9a9bf96ced17b919585504aa09707193` |
| `install.sh` | `b65e79902d10a63f0d5fdf0760c41b8c` |

On XO-1: `md5sum <file>`

---

## After install

```sh
/opt/xo1-tls/bin/curl -V
/opt/xo1-tls/bin/curl -I https://example.com
. /opt/xo1-tls/bin/xo1-env.sh
/opt/xo1-tls/bin/xo1-browse
```

## Automate from Windows (SSH)

```powershell
ssh xo1 @"
U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
U=\"\$U/kenneyhe2/olpc/main/install.sh\"
echo \"\$U\"
wget -O install.sh \"\$U\" && chmod +x install.sh && sudo ./install.sh
"@
```

## Host

Hyper-V platform (`vmms`); Docker Desktop here uses a WSL2 Linux VM on that platform.
