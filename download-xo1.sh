#!/bin/sh
# Fetch kenneyhe2/olpc artifacts on OLPC XO-1 (Geode / i586) when system curl/TLS is broken.
#
# Bootstrap: plain HTTP wget via pkgforge (no TLS on XO), extract curl/OpenSSL to /opt,
# then use /opt/xo1-tls/bin/curl for the remaining files.
#
# Usage on XO-1:
#   U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
#   U="$U/kenneyhe2/olpc/main/download-xo1.sh"
#   wget -O download-xo1.sh "$U" && chmod +x download-xo1.sh && sudo ./download-xo1.sh
#
# If HTTP wget fails: SCP xo-openssl-curl-xo1-i586-glibc212.tar.gz from Windows (see README).
set -eu

REPO=https://raw.githubusercontent.com/kenneyhe2/olpc/main
PKGFORGE='http://http.pkgforge.dev/https://raw.githubusercontent.com'
WORKDIR=${WORKDIR:-/tmp/olpc-fetch}
CURL_TGZ=xo-openssl-curl-xo1-i586-glibc212.tar.gz

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

pkgforge_url() {
  echo "$PKGFORGE/kenneyhe2/olpc/main/$1"
}

xo_curl_ok() {
  [ -x /opt/xo1-tls/bin/curl ] && \
    LD_LIBRARY_PATH=/opt/xo1-tls/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} \
      /opt/xo1-tls/bin/curl -V >/dev/null 2>&1
}

wget_http() {
  file=$1
  dest=$2
  url=$(pkgforge_url "$file")
  if ! command -v wget >/dev/null 2>&1; then
    echo "ERROR: wget not found."
    scp_fallback "$dest"
    exit 1
  fi
  echo "==> URL: $url"
  if ! wget -O "$dest" "$url"; then
    echo "ERROR: wget failed for $url"
    scp_fallback "$dest"
    exit 1
  fi
}

scp_fallback() {
  dest=$1
  echo ""
  echo "Bootstrap tarball must be copied from a machine with working network."
  echo "  File needed: $dest"
  echo ""
  echo "HTTP wget on XO (build URL in pieces):"
  echo "  U='http://http.pkgforge.dev/https://raw.githubusercontent.com'"
  echo "  U=\"\$U/kenneyhe2/olpc/main/$dest\""
  echo "  echo \"\$U\""
  echo "  wget -O $dest \"\$U\""
  echo ""
  echo "Or from Windows (after fixing SSH — see README):"
  echo "  scp %TEMP%\\$dest xo1:/tmp/$dest"
  echo "  sudo tar -C / -xzf /tmp/$dest"
  echo "  sudo $0"
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
  echo "==> Phase 1: bootstrap curl/OpenSSL via HTTP wget (pkgforge)"
  wget_http "$CURL_TGZ" "$CURL_TGZ"
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
