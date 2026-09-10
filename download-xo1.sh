#!/bin/sh
# Fetch kenneyhe2/olpc artifacts on OLPC XO-1 (Geode / i586) when system curl/TLS is broken.
#
# Bootstrap: wget --no-check-certificate for the curl/OpenSSL tarball only, extract to /opt,
# then use /opt/xo1-tls/bin/curl for the remaining files.
#
# Usage on XO-1:
#   wget --no-check-certificate -O download-xo1.sh \
#     https://raw.githubusercontent.com/kenneyhe2/olpc/main/download-xo1.sh
#   chmod +x download-xo1.sh
#   sudo ./download-xo1.sh
set -eu

REPO=https://raw.githubusercontent.com/kenneyhe2/olpc/main
WORKDIR=${WORKDIR:-/tmp/olpc-fetch}
CURL_TGZ=xo-openssl-curl-xo1-i586.tar.gz

ARTIFACTS="
$CURL_TGZ
xo-gtk2-xo1-i586-glibc212.tar.gz
xo-xulrunner-1.9.2-geode-i586.tar.gz
install.sh
"

need_root() {
  [ "$(id -u)" -eq 0 ] || {
    echo "Run as root: sudo $0"
    exit 1
  }
}

xo_curl_ok() {
  [ -x /opt/xo1-tls/bin/curl ] && \
    LD_LIBRARY_PATH=/opt/xo1-tls/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} \
      /opt/xo1-tls/bin/curl -V >/dev/null 2>&1
}

wget_insecure() {
  url=$1
  dest=$2
  if command -v wget >/dev/null 2>&1; then
    wget --no-check-certificate -O "$dest" "$url"
    return 0
  fi
  echo "ERROR: wget not found; install wget or copy $dest from another machine"
  exit 1
}

xo_curl() {
  LD_LIBRARY_PATH=/opt/xo1-tls/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} \
    /opt/xo1-tls/bin/curl -fSL "$@"
}

need_root
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "==> Work directory: $WORKDIR"

if ! xo_curl_ok; then
  echo "==> Phase 1: bootstrap curl/OpenSSL via wget (TLS verify disabled)"
  wget_insecure "$REPO/$CURL_TGZ" "$CURL_TGZ"
  echo "==> Extract $CURL_TGZ -> /opt/xo1-tls"
  tar -C / -xzf "$CURL_TGZ"
  if ! xo_curl_ok; then
    echo "ERROR: /opt/xo1-tls/bin/curl still not runnable after extract"
    exit 1
  fi
  echo "==> Bootstrap curl:"
  LD_LIBRARY_PATH=/opt/xo1-tls/lib /opt/xo1-tls/bin/curl -V | head -1
else
  echo "==> Bootstrap curl already present at /opt/xo1-tls/bin/curl"
fi

echo "==> Phase 2: fetch remaining artifacts with bundled curl"
for name in $ARTIFACTS; do
  [ "$name" = "$CURL_TGZ" ] && continue
  echo "    -> $name"
  xo_curl -o "$name" "$REPO/$name"
done

echo "==> Done. Artifacts in $WORKDIR:"
ls -lh $ARTIFACTS 2>/dev/null || ls -lh

echo ""
echo "Install:"
echo "  cd $WORKDIR && chmod +x install.sh && ./install.sh"
