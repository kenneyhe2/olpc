#!/bin/sh
# Fetch and deploy XO-1 i586 libs (curl + GTK2 + xulrunner) on OLPC XO-1.
#
# On XO-1 — plain HTTP wget (no TLS on the XO):
#   U='http://http.pkgforge.dev/https://raw.githubusercontent.com'
#   U="$U/kenneyhe2/olpc/main/install.sh"
#   echo "$U"
#   wget -O install.sh "$U"
#   chmod +x install.sh && sudo ./install.sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO=https://raw.githubusercontent.com/kenneyhe2/olpc/main
PKGFORGE='http://http.pkgforge.dev/https://raw.githubusercontent.com'
CURL_TGZ=xo-openssl-curl-xo1-i586-glibc212.tar.gz
GTK_TGZ=xo-gtk2-xo1-i586-glibc212.tar.gz
XUL_TGZ=xo-xulrunner-1.9.2-geode-i586.tar.gz

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
    scp_hint "$file"
    exit 1
  fi
  echo "==> URL: $url"
  if ! wget -O "$dest" "$url"; then
    echo "ERROR: wget failed for $url"
    scp_hint "$file"
    exit 1
  fi
}

scp_hint() {
  file=$1
  echo ""
  echo "Copy $file from another machine, or retry HTTP wget:"
  echo "  U='http://http.pkgforge.dev/https://raw.githubusercontent.com'"
  echo "  U=\"\$U/kenneyhe2/olpc/main/$file\""
  echo "  echo \"\$U\""
  echo "  wget -O $file \"\$U\""
}

xo_curl() {
  LD_LIBRARY_PATH=/opt/xo1-tls/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} \
    /opt/xo1-tls/bin/curl -fSL "$@"
}

fetch_artifacts() {
  curl_local=$(pick 'xo-openssl-curl-xo1-i586*.tar.gz')
  gtk_local=$(pick 'xo-gtk2-xo1-i586*.tar.gz')
  xul_local=$(pick 'xo-xulrunner-*-geode-i586.tar.gz')
  [ -n "$xul_local" ] || xul_local=$(pick 'xo-xulrunner-*.tar.gz')

  if [ -n "$curl_local" ] && [ -n "$gtk_local" ] && [ -n "$xul_local" ]; then
    return 0
  fi

  echo "==> Fetch artifacts into $HERE"

  if [ -z "$curl_local" ]; then
    if ! xo_curl_ok; then
      echo "==> Bootstrap curl/OpenSSL via HTTP wget (pkgforge)"
      wget_http "$CURL_TGZ" "$HERE/$CURL_TGZ"
      echo "==> Extract $CURL_TGZ -> /opt/xo1-tls"
      tar -C / -xzf "$HERE/$CURL_TGZ"
      if ! xo_curl_ok; then
        echo "ERROR: /opt/xo1-tls/bin/curl not runnable after extract"
        exit 1
      fi
      LD_LIBRARY_PATH=/opt/xo1-tls/lib /opt/xo1-tls/bin/curl -V | head -1
    fi
    if [ ! -f "$HERE/$CURL_TGZ" ]; then
      echo "    -> $CURL_TGZ"
      xo_curl -o "$HERE/$CURL_TGZ" "$REPO/$CURL_TGZ"
    fi
  fi

  if [ -z "$gtk_local" ]; then
    echo "    -> $GTK_TGZ"
    xo_curl -o "$HERE/$GTK_TGZ" "$REPO/$GTK_TGZ"
  fi

  if [ -z "$xul_local" ]; then
    echo "    -> $XUL_TGZ"
    xo_curl -o "$HERE/$XUL_TGZ" "$REPO/$XUL_TGZ"
  fi
}

deploy_artifacts() {
  CURL_TGZ_PATH=$(pick 'xo-openssl-curl-xo1-i586*.tar.gz')
  GTK_TGZ_PATH=$(pick 'xo-gtk2-xo1-i586*.tar.gz')
  XUL_TGZ_PATH=$(pick 'xo-xulrunner-*-geode-i586.tar.gz')
  [ -n "$XUL_TGZ_PATH" ] || XUL_TGZ_PATH=$(pick 'xo-xulrunner-*.tar.gz')

  [ -n "$CURL_TGZ_PATH" ] || {
    echo "missing openssl/curl tarball (xo-openssl-curl-xo1-i586*.tar.gz)"
    exit 1
  }
  [ -n "$GTK_TGZ_PATH" ] || {
    echo "missing gtk2 tarball (xo-gtk2-xo1-i586*.tar.gz)"
    exit 1
  }

  echo "==> Extract $CURL_TGZ_PATH"
  tar -C / -xzf "$CURL_TGZ_PATH"
  echo "==> Extract $GTK_TGZ_PATH"
  tar -C / -xzf "$GTK_TGZ_PATH"
  if [ -n "$XUL_TGZ_PATH" ]; then
    echo "==> Extract $XUL_TGZ_PATH"
    tar -C / -xzf "$XUL_TGZ_PATH"
  else
    echo "WARN: no xulrunner tarball (Sugar Browse engine not installed)"
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
# Execute to apply env, kill prior Browse, and launch:
#   /opt/xo1-tls/bin/xo1-browse
#   /opt/xo1-tls/bin/xo1-browse http://www.yahoo.com
#   /opt/xo1-tls/bin/xo1-browse -u http://www.yahoo.com

_xo1_is_sourced() {
  if [ -n "${BASH_VERSION:-}" ]; then
    [ "${BASH_SOURCE[0]:-}" != "${0}" ]
  else
    case "$0" in */xo1-browse|xo1-browse) return 1 ;; esac
    return 0
  fi
}

_xo1_apply_env() {
  # Inline GTK paths — do not source gtk2-env.sh (dirname -b when $0 is "-bash").
  GTK=/opt/xo1-gtk2
  export GDK_PIXBUF_MODULEDIR="${GTK}/lib/gdk-pixbuf-2.0/2.10.0/loaders"
  export GTK_PATH="${GTK}/lib/gtk-2.0"
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

_xo1_normalize_uri_args() {
  _XO1_URI=
  _XO1_EXTRA=
  while [ $# -gt 0 ]; do
    case "$1" in
      -u|--uri)
        if [ -z "${2:-}" ]; then
          echo "xo1-browse: missing URI after $1" >&2
          exit 1
        fi
        _XO1_URI=$2
        shift 2
        ;;
      http://*|https://*|file://*)
        _XO1_URI=$1
        shift
        ;;
      *)
        _XO1_EXTRA="${_XO1_EXTRA:+$_XO1_EXTRA }$1"
        shift
        ;;
    esac
  done
}

_xo1_kill_browse() {
  command -v pgrep >/dev/null 2>&1 || return 0

  _xo1_signal_pids() {
    sig=$1
    pattern=$2
    pids=$(pgrep -u "$(id -u)" -f "$pattern" 2>/dev/null || true)
    [ -z "$pids" ] && return 0
    for pid in $pids; do
      [ "$pid" -eq "$$" ] && continue
      if [ -n "$sig" ]; then
        kill "$sig" "$pid" 2>/dev/null || true
      else
        kill "$pid" 2>/dev/null || true
      fi
    done
  }

  for pattern in \
    'sugar-activity[[:space:]]+Browse' \
    'sugar-activity[[:space:]]+webactivity\.WebActivity' \
    'org\.laptop\.WebActivity' \
    'Browse\.activity' \
    '/opt/xo1-xulrunner'
  do
    _xo1_signal_pids '' "$pattern"
  done

  sleep 1

  for pattern in \
    'sugar-activity[[:space:]]+Browse' \
    'sugar-activity[[:space:]]+webactivity\.WebActivity' \
    'org\.laptop\.WebActivity' \
    'Browse\.activity' \
    '/opt/xo1-xulrunner'
  do
    _xo1_signal_pids -9 "$pattern"
  done
}

_xo1_launch_browse() {
  if [ -z "${DISPLAY:-}" ]; then
    echo "xo1-browse needs the Sugar desktop (X11), not an SSH shell." >&2
    echo "Run from the XO-1 screen, or: export DISPLAY=:0" >&2
    exit 1
  fi

  _xo1_normalize_uri_args "$@"
  _xo1_kill_browse

  if command -v sugar-launch >/dev/null 2>&1 && _xo1_sugar_shell_running; then
    if [ -n "${_XO1_URI:-}" ]; then
      exec sugar-launch org.laptop.WebActivity -u "$_XO1_URI" $_XO1_EXTRA
    else
      exec sugar-launch org.laptop.WebActivity $_XO1_EXTRA
    fi
  fi
  if command -v sugar-activity >/dev/null 2>&1; then
    if [ -n "${_XO1_URI:-}" ]; then
      exec sugar-activity Browse -u "$_XO1_URI" $_XO1_EXTRA
    else
      exec sugar-activity Browse $_XO1_EXTRA
    fi
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
}

need_root
cd "$HERE"
fetch_artifacts
deploy_artifacts

echo "==> Done"
echo "Smoke:"
echo "  /opt/xo1-tls/bin/curl -V"
echo "  /opt/xo1-tls/bin/curl -I https://example.com"
echo "  . /opt/xo1-tls/bin/xo1-browse && /opt/xo1-tls/bin/curl -I https://example.com"
echo "  /opt/xo1-tls/bin/xo1-browse http://www.yahoo.com   # kill prior Browse, open URL"
echo "  sh acceptance-test-xo1-browse.sh"
