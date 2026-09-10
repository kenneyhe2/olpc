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

## SSH from Windows (OpenSSH 9.x → XO-1 OpenSSH 5.5)

XO-1 ships **OpenSSH 5.5**, which only offers legacy host keys (`ssh-rsa`, `ssh-dss`). Modern Windows OpenSSH disables those, so you see:

```text
no matching host key type found. Their offer: ssh-rsa,ssh-dss
```

XO-1 also does **not** accept `ed25519` keys (added in OpenSSH 6.5). Use **RSA** for `authorized_keys`.

### 1. One-shot test (PowerShell)

**Quote the `-o` values** — PowerShell treats bare commas as array separators and breaks algorithm lists.

```powershell
ssh -o "HostKeyAlgorithms=+ssh-rsa,+ssh-dss" -o "PubkeyAcceptedAlgorithms=+ssh-rsa" olpc@10.0.0.25
```

If that connects but a later step fails on ciphers/KEX, use the full `Host` block below.

### 2. Persistent config (recommended)

Create or edit `C:\Users\citadelone\.ssh\config`:

```sshconfig
Host xo1 olpc-xo1 10.0.0.25
    HostName 10.0.0.25
    User olpc
    IdentityFile ~/.ssh/id_rsa_olpc

    # Legacy algorithms required for OpenSSH 5.5 on XO-1
    HostKeyAlgorithms +ssh-rsa,+ssh-dss
    PubkeyAcceptedAlgorithms +ssh-rsa
    KexAlgorithms +diffie-hellman-group-exchange-sha256,+diffie-hellman-group14-sha1,+diffie-hellman-group-exchange-sha1,+diffie-hellman-group1-sha1
    Ciphers +aes128-ctr,+aes256-ctr,+aes128-cbc,+aes256-cbc
    MACs +hmac-sha2-256,hmac-sha1

    # Automation on a trusted LAN only (skip host-key prompts)
    StrictHostKeyChecking accept-new
```

For fully unattended scripts on a trusted network, change the last line to:

```sshconfig
    StrictHostKeyChecking no
    UserKnownHostsFile NUL
```

Then connect with:

```powershell
ssh xo1
```

### 3. RSA key + authorized_keys (passwordless automation)

Generate an RSA key (do **not** reuse `id_ed25519` — XO-1 cannot use it):

```powershell
ssh-keygen -t rsa -b 2048 -f $env:USERPROFILE\.ssh\id_rsa_olpc
```

Copy the public key to the XO (first time, use password auth after the config above):

```powershell
type $env:USERPROFILE\.ssh\id_rsa_olpc.pub | ssh xo1 "mkdir -p .ssh && chmod 700 .ssh && cat >> .ssh/authorized_keys && chmod 600 .ssh/authorized_keys"
```

Or paste manually on the XO terminal:

```sh
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# paste one line from id_rsa_olpc.pub into ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Verify passwordless login:

```powershell
ssh -i $env:USERPROFILE\.ssh\id_rsa_olpc xo1 whoami
```

### 4. Automate repo download over SSH

```powershell
ssh xo1 "wget --no-check-certificate -O download-xo1.sh https://raw.githubusercontent.com/kenneyhe2/olpc/main/download-xo1.sh && chmod +x download-xo1.sh && sudo ./download-xo1.sh"
```

## Host
Hyper-V platform (`vmms`); Docker Desktop here uses a WSL2 Linux VM on that platform. Long builds polled every 3 minutes.
