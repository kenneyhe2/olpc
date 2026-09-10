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

cat >/opt/xo1-tls/bin/xo1-browse <<'EOF'
#!/bin/sh
# XO-1 TLS/GTK2/XULRunner environment and Sugar Browse launcher.
#
# Source for library paths only (does not launch Browse):
#   . /opt/xo1-tls/bin/xo1-browse
#
# Execute to apply env and launch Browse:
#   /opt/xo1-tls/bin/xo1-browse

_xo1_is_sourced() {
  if [ -n "${BASH_VERSION:-}" ]; then
    [ "${BASH_SOURCE[0]:-}" != "${0}" ]
  else
    case "$0" in */xo1-browse|xo1-browse) return 1 ;; esac
    return 0
  fi
}

_xo1_apply_env() {
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
}

_xo1_sugar_shell_running() {
  command -v dbus-send >/dev/null 2>&1 || return 1
  dbus-send --session --print-reply --dest=org.freedesktop.DBus \
    /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner \
    string:org.laptop.Shell 2>/dev/null \
    | grep -q 'boolean true'
}

_xo1_launch_browse() {
  if command -v sugar-launch >/dev/null 2>&1 && _xo1_sugar_shell_running; then
    exec sugar-launch org.laptop.WebActivity "$@"
  fi
  if command -v sugar-activity >/dev/null 2>&1; then
    exec sugar-activity Browse "$@"
  fi
  echo "Sugar Browse unavailable (Sugar shell not running or launcher missing)." >&2
  echo "Source for TLS/GTK paths only: . /opt/xo1-tls/bin/xo1-browse" >&2
  exit 1
}

_xo1_apply_env

if _xo1_is_sourced; then
  return 0 2>/dev/null || exit 0
fi

_xo1_launch_browse "$@"
EOF
chmod 755 /opt/xo1-tls/bin/xo1-browse

cat >/opt/xo1-tls/bin/xo1-env.sh <<'EOF'
# Compatibility wrapper — prefer: . /opt/xo1-tls/bin/xo1-browse
. /opt/xo1-tls/bin/xo1-browse
EOF
chmod 755 /opt/xo1-tls/bin/xo1-env.sh

echo "==> Done"
echo "Smoke:"
echo "  /opt/xo1-tls/bin/curl -V"
echo "  /opt/xo1-tls/bin/curl -I https://example.com"
echo "  . /opt/xo1-tls/bin/xo1-browse && /opt/xo1-tls/bin/curl -I https://example.com"
echo "  /opt/xo1-tls/bin/xo1-browse   # launch Browse (Sugar session required)"
echo "  sh acceptance-test-xo1-browse.sh           # acceptance (root console OK)"
echo "  sh acceptance-test-xo1-browse.sh --live    # + live Browse (olpc in Sugar)"
