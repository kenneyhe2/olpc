#!/bin/sh
# Deploy XO-1 i586 dynamic lib tarballs under /opt (curl + GTK2 + xulrunner).
# Usage (on XO): copy this script next to the xo-*.tar.gz files, then:
#   sudo ./install.sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

need_root() {
  [ "$(id -u)" -eq 0 ] || {
    echo "Run as root: sudo $0"
    exit 1
  }
}

pick() {
  # shellcheck disable=SC2086
  ls -1 "$HERE"/$1 2>/dev/null | head -1 || true
}

need_root

CURL_TGZ=$(pick 'xo-openssl-curl-xo1-i586*.tar.gz')
GTK_TGZ=$(pick 'xo-gtk2-xo1-i586*.tar.gz')
XUL_TGZ=$(pick 'xo-xulrunner-*-geode-i586.tar.gz')
[ -n "$XUL_TGZ" ] || XUL_TGZ=$(pick 'xo-xulrunner-*.tar.gz')

[ -n "$CURL_TGZ" ] || {
  echo "missing openssl/curl tarball (xo-openssl-curl-xo1-i586*.tar.gz)"
  exit 1
}
[ -n "$GTK_TGZ" ] || {
  echo "missing gtk2 tarball (xo-gtk2-xo1-i586*.tar.gz)"
  exit 1
}

echo "==> Extract $CURL_TGZ"
tar -C / -xzf "$CURL_TGZ"
echo "==> Extract $GTK_TGZ"
tar -C / -xzf "$GTK_TGZ"
if [ -n "$XUL_TGZ" ]; then
  echo "==> Extract $XUL_TGZ"
  tar -C / -xzf "$XUL_TGZ"
else
  echo "WARN: no xulrunner tarball yet (Sugar Browse engine not installed)"
fi

if ls /opt/xo1-gtk2/lib/libgtk-3.so* >/dev/null 2>&1; then
  echo "ERROR: libgtk-3 found under /opt/xo1-gtk2 (GTK3 not allowed)"
  exit 1
fi

mkdir -p /opt/xo1-tls/bin

cat >/opt/xo1-tls/bin/xo1-env.sh <<'EOF'
# source: . /opt/xo1-tls/bin/xo1-env.sh
[ -f /opt/xo1-gtk2/gtk2-env.sh ] && . /opt/xo1-gtk2/gtk2-env.sh
XP=/opt/xo1-xulrunner
for d in "$XP/lib" "$XP"; do
  [ -d "$d" ] || continue
  case ":${LD_LIBRARY_PATH:-}:" in *":$d:"*) ;; *)
    LD_LIBRARY_PATH="$d${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
  esac
done
for d in /opt/xo1-xulrunner/lib/xulrunner-*; do
  [ -d "$d" ] || continue
  case ":${LD_LIBRARY_PATH:-}:" in *":$d:"*) ;; *)
    LD_LIBRARY_PATH="$d${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
  esac
done
LD_LIBRARY_PATH="/opt/xo1-gtk2/lib:/opt/xo1-tls/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH
if [ -d /opt/xo1-xulrunner ]; then
  MOZILLA_FIVE_HOME=$(ls -d /opt/xo1-xulrunner/lib/xulrunner-* 2>/dev/null | head -1 || true)
  [ -n "${MOZILLA_FIVE_HOME:-}" ] || MOZILLA_FIVE_HOME=/opt/xo1-xulrunner
  export MOZILLA_FIVE_HOME
fi
export PATH="/opt/xo1-tls/bin:${PATH:-}"
EOF
chmod 755 /opt/xo1-tls/bin/xo1-env.sh

cat >/opt/xo1-tls/bin/xo1-browse <<'EOF'
#!/bin/sh
. /opt/xo1-tls/bin/xo1-env.sh
if command -v sugar-launch >/dev/null 2>&1; then
  exec sugar-launch org.laptop.WebActivity "$@"
fi
if command -v sugar-activity >/dev/null 2>&1; then
  exec sugar-activity Browse "$@"
fi
echo "Sugar Browse launcher not found (sugar-launch / sugar-activity)"
exit 1
EOF
chmod 755 /opt/xo1-tls/bin/xo1-browse

echo "==> Done"
echo "Smoke:"
echo "  /opt/xo1-tls/bin/curl -V"
echo "  /opt/xo1-tls/bin/curl -I https://example.com"
echo "  . /opt/xo1-tls/bin/xo1-env.sh && /opt/xo1-tls/bin/xo1-browse"
