# XO-1 i586 curl + Sugar Browse (GTK2)

Dynamically linked libraries for OLPC XO-1 (**Geode / i586**), **curl**, and **Sugar Browse** (GTK2 / XULRunner). No GTK3. No Firefox deliverable.

## Repo files

| File | Purpose |
|------|---------|
| `install.sh` | **Only install script** — HTTP wget bootstrap, fetch tarballs, extract to `/opt` |
| `xo-openssl-curl-xo1-i586-glibc212.tar.gz` | OpenSSL 1.1.1w + curl 7.88.1 (downloaded by `install.sh`) |
| `xo-gtk2-xo1-i586-glibc212.tar.gz` | `libgtk-x11-2.0.so.0` + deps |
| `xo-xulrunner-1.9.2-geode-i586.tar.gz` | FC14 xulrunner for Browse |
| `ssh-config-windows-xo1.example` | Windows SSH config template for XO-1 |
| `ssh-config-xo1-only` | Standalone SSH config (`ssh -F ...`) |
| `fix-ssh-config-windows.ps1` | Auto-patch broken Windows SSH config |

---

## Quick start

1. **Windows** — fix SSH config ([below](#ssh-from-windows-openssh-9x--xo-1-openssh-55)), then `ssh xo1`
2. **XO-1** — HTTP wget `install.sh`, run it

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

### What `install.sh` does

1. **HTTP wget** (pkgforge, no TLS on XO) — bootstrap `xo-openssl-curl-xo1-i586-glibc212.tar.gz`
2. **Bundled curl** — fetch gtk2 + xulrunner tarballs over HTTPS
3. **Deploy** — extract under `/opt`, write single `xo1-browse` (env + kill prior Browse + launcher)

Skips download for any tarball already in the same directory as `install.sh`.

### After install

```sh
/opt/xo1-tls/bin/curl -V
/opt/xo1-tls/bin/curl -I https://example.com
```

**Sugar Browse** — one script (`xo1-browse` includes env setup). Run on the XO-1 desktop as `olpc` (not over SSH):

```sh
# On the XO-1 screen (Sugar), in Terminal:
/opt/xo1-tls/bin/xo1-browse http://www.yahoo.com
```

Kills any existing Browse for the current user, then opens the URL. Env-only (e.g. for curl):

```sh
. /opt/xo1-tls/bin/xo1-browse
/opt/xo1-tls/bin/curl -I https://example.com
```

Acceptance test after install:

```sh
sh acceptance-test-xo1-browse.sh           # root console OK
sh acceptance-test-xo1-browse.sh --live      # olpc in Sugar
```

Over SSH, executing `xo1-browse` prints a DISPLAY warning — expected. Sourcing still works for curl.

> **Note:** `main` on GitHub may still serve the old deploy-only `install.sh` (~2853 bytes) until the feature branch is merged. The current script is ~5600 bytes and includes HTTP wget fetch. Verify with `wc -c install.sh` after wget.

### HTTP wget helper (individual tarballs)

Build URL in pieces — `echo` then `wget` (plain HTTP):

```sh
pkgforge() {
  U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
  U="$U/kenneyhe2/olpc/main/$1"
  echo "$U"
  wget -O "$1" "$U"
}

pkgforge xo-openssl-curl-xo1-i586-glibc212.tar.gz
```

Then run `sudo ./install.sh` (or place all tarballs locally and run install).

### Fallback — SCP from Windows

If HTTP wget fails on the XO, copy files after SSH works:

```powershell
$TGZ = "xo-openssl-curl-xo1-i586-glibc212.tar.gz"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/kenneyhe2/olpc/main/$TGZ" -OutFile $env:TEMP\$TGZ
scp $env:TEMP\$TGZ xo1:/tmp/
```

On XO: `wget` or `scp` `install.sh` too, place tarballs in the same directory, `sudo ./install.sh`.

### Verify checksums (optional)

| File | MD5 |
|------|-----|
| `install.sh` | `c7919316eca505a8a31b5a94e9d77eaf` |
| `xo-openssl-curl-xo1-i586-glibc212.tar.gz` | `ae2950be7950f33fee5adc4fdc50adf9` |
| `xo-gtk2-xo1-i586-glibc212.tar.gz` | `414c040cdd79322f229ff086acbbeb0a` |
| `xo-xulrunner-1.9.2-geode-i586.tar.gz` | `9a9bf96ced17b919585504aa09707193` |

On XO-1: `md5sum <file>`

### Automate from Windows (SSH)

```powershell
ssh xo1 @"
U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
U=\"\$U/kenneyhe2/olpc/main/install.sh\"
echo \"\$U\"
wget -O install.sh \"\$U\" && chmod +x install.sh && sudo ./install.sh
"@
```

---

## SSH from Windows (OpenSSH 9.x → XO-1 OpenSSH 5.5)

XO-1 runs **OpenSSH 5.5** (legacy `ssh-rsa` only for modern clients). Windows **OpenSSH 9.5+** disables that by default. XO-1 does **not** accept `ed25519` keys — use **RSA** for `authorized_keys`.

### Connect now (skip broken config)

If `ssh xo1` dies on config lines 10/12/13, your `C:\Users\citadelone\.ssh\config` is still wrong. OpenSSH reads it **before** `-o` flags. Bypass it:

```powershell
ssh -F NUL -o "HostKeyAlgorithms=+ssh-rsa" -o "PubkeyAcceptedAlgorithms=+ssh-rsa" -o "KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1" olpc@10.0.0.25
```

### Persistent SSH config

Create or edit `C:\Users\citadelone\.ssh\config` (or run `.\fix-ssh-config-windows.ps1`):

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

After saving the config, connect with:

```powershell
ssh xo1
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

## Host

Hyper-V platform (`vmms`); Docker Desktop here uses a WSL2 Linux VM on that platform.
