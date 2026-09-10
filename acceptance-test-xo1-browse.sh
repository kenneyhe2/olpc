#!/bin/sh
# Acceptance test for /opt/xo1-tls/bin/xo1-browse on an XO-1 after install.sh.
#
# Run from a root console (tests sourcing + graceful launch failure):
#   sh acceptance-test-xo1-browse.sh
#
# Run from the olpc Sugar session (tests live Browse launch):
#   sh acceptance-test-xo1-browse.sh --live
#
# Exit 0 only when all non-skipped checks pass.
set -eu

BROWSE=/opt/xo1-tls/bin/xo1-browse
LIVE=0
[ "${1:-}" = "--live" ] && LIVE=1
export DISPLAY=${DISPLAY:-:0}

PASS=0
FAIL=0
SKIP=0

pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo "SKIP: $1"
  SKIP=$((SKIP + 1))
}

sugar_shell_running() {
  command -v dbus-send >/dev/null 2>&1 || return 1
  dbus-send --session --print-reply --dest=org.freedesktop.DBus \
    /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner \
    string:org.laptop.Shell 2>/dev/null \
    | grep -q 'boolean true'
}

echo "==> xo1-browse acceptance test"
echo "    browse=$BROWSE live=$LIVE"
echo

# --- installed artifacts ---
if [ -x "$BROWSE" ]; then
  pass "xo1-browse exists and is executable"
else
  fail "xo1-browse missing or not executable ($BROWSE)"
fi

if [ ! -f /opt/xo1-tls/bin/xo1-env.sh ]; then
  pass "single script only (no xo1-env.sh wrapper)"
else
  fail "xo1-env.sh should be removed; use xo1-browse only"
fi

for libdir in /opt/xo1-gtk2/lib /opt/xo1-tls/lib; do
  if [ -d "$libdir" ]; then
    pass "library directory present ($libdir)"
  else
    fail "library directory missing ($libdir)"
  fi
done

if [ -d /opt/xo1-xulrunner ]; then
  pass "xulrunner tree present (/opt/xo1-xulrunner)"
else
  skip "xulrunner tree missing (Browse engine not installed)"
fi

# --- sourcing must not launch Browse or crash ---
if (
  unset LD_LIBRARY_PATH MOZILLA_FIVE_HOME
  OLD_PATH=$PATH
  . "$BROWSE"
  case ":${LD_LIBRARY_PATH:-}:" in
    *:/opt/xo1-gtk2/lib:*|*:/opt/xo1-gtk2/lib) ;;
    *)
      echo "LD_LIBRARY_PATH missing /opt/xo1-gtk2/lib: ${LD_LIBRARY_PATH:-<unset>}"
      exit 1
      ;;
  esac
  case ":${LD_LIBRARY_PATH:-}:" in
    *:/opt/xo1-tls/lib:*|*:/opt/xo1-tls/lib) ;;
    *)
      echo "LD_LIBRARY_PATH missing /opt/xo1-tls/lib: ${LD_LIBRARY_PATH:-<unset>}"
      exit 1
      ;;
  esac
  case ":${PATH:-}:" in
    *:/opt/xo1-tls/bin:*|*:/opt/xo1-tls/bin) ;;
    *)
      echo "PATH missing /opt/xo1-tls/bin: ${PATH:-<unset>}"
      exit 1
      ;;
  esac
  if [ -d /opt/xo1-xulrunner ] && [ -z "${MOZILLA_FIVE_HOME:-}" ]; then
    echo "MOZILLA_FIVE_HOME unset after source"
    exit 1
  fi
); then
  pass "sourcing xo1-browse sets env without launching Browse"
else
  fail "sourcing xo1-browse failed env checks or crashed"
fi

# --- executed outside Sugar must fail gracefully (no DBus traceback) ---
if sugar_shell_running; then
  skip "executed outside Sugar (Sugar shell is running in this session)"
else
  OUT=$(mktemp /tmp/xo1-browse-out.XXXXXX)
  ERR=$(mktemp /tmp/xo1-browse-err.XXXXXX)
  set +e
  "$BROWSE" >"$OUT" 2>"$ERR"
  RC=$?
  set -e

  if [ "$RC" -eq 1 ]; then
    pass "executed outside Sugar exits 1 (expected)"
  else
    fail "executed outside Sugar should exit 1, got $RC"
  fi

  if grep -q 'Sugar Browse unavailable' "$ERR"; then
    pass "executed outside Sugar prints friendly error"
  else
    fail "executed outside Sugar missing friendly error message"
  fi

  if grep -qi 'traceback\|dbus\.exceptions' "$ERR"; then
    fail "executed outside Sugar raised DBus/Python traceback"
  else
    pass "executed outside Sugar avoids DBus traceback"
  fi

  rm -f "$OUT" "$ERR"
fi

# --- URL argument is passed to sugar-activity as -u (Sugar API) ---
MOCK_BIN=$(mktemp -d /tmp/xo1-mock-bin.XXXXXX)
MOCK_LOG=$(mktemp /tmp/xo1-mock-log.XXXXXX)
cat >"$MOCK_BIN/sugar-activity" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >"$MOCK_LOG"
exit 0
EOF
chmod +x "$MOCK_BIN/sugar-activity"
if (
  export PATH="$MOCK_BIN:/usr/bin:/bin"
  unset LD_LIBRARY_PATH MOZILLA_FIVE_HOME
  "$BROWSE" http://www.yahoo.com >/dev/null 2>&1
  grep -q 'Browse -u http://www.yahoo.com' "$MOCK_LOG"
); then
  pass "http URL argument forwarded as Browse -u URI"
else
  fail "http URL argument not forwarded as Browse -u URI (got: $(cat "$MOCK_LOG" 2>/dev/null || echo missing))"
fi
rm -rf "$MOCK_BIN" "$MOCK_LOG"

# --- kill existing Browse before launch ---
FAKE_STUB=/tmp/xo1-browse-kill-stub
rm -rf "$FAKE_STUB"
mkdir -p "$FAKE_STUB/Browse.activity"
cat >"$FAKE_STUB/Browse.activity/run" <<'EOF'
#!/bin/sh
sleep 120
EOF
chmod +x "$FAKE_STUB/Browse.activity/run"
"$FAKE_STUB/Browse.activity/run" &
FAKE_PID=$!
sleep 1
MOCK_BIN2=$(mktemp -d /tmp/xo1-mock-bin2.XXXXXX)
cat >"$MOCK_BIN2/sugar-activity" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$MOCK_BIN2/sugar-activity"
if (
  export PATH="$MOCK_BIN2:/usr/bin:/bin"
  /opt/xo1-tls/bin/xo1-browse http://www.yahoo.com >/dev/null 2>&1
  kill -0 "$FAKE_PID" 2>/dev/null
); then
  fail "kill-all-then-launch left existing Browse.activity process running"
  kill -9 "$FAKE_PID" 2>/dev/null || true
else
  pass "kill-all-then-launch stops existing Browse before new launch"
  wait "$FAKE_PID" 2>/dev/null || true
fi
rm -rf "$FAKE_STUB" "$MOCK_BIN2"

# --- TLS curl still works with sourced env ---
if [ -x /opt/xo1-tls/bin/curl ]; then
  if (
    . "$BROWSE"
    /opt/xo1-tls/bin/curl -fsSI --max-time 20 https://example.com >/dev/null
  ); then
    pass "curl https://example.com works with sourced xo1-browse env"
  else
    fail "curl https://example.com failed with sourced xo1-browse env"
  fi
else
  skip "curl binary missing (/opt/xo1-tls/bin/curl)"
fi

# --- optional live Browse launch (Sugar session, olpc user) ---
if [ "$LIVE" -eq 0 ]; then
  skip "live Browse launch (re-run with --live from olpc Sugar session)"
elif ! sugar_shell_running; then
  fail "live mode requested but org.laptop.Shell is not on session bus"
elif [ "$(id -un)" != "olpc" ]; then
  skip "live Browse launch (run as olpc user inside Sugar, not $(id -un))"
elif ! command -v sugar-launch >/dev/null 2>&1 && ! command -v sugar-activity >/dev/null 2>&1; then
  fail "live mode: neither sugar-launch nor sugar-activity found"
else
  LOG=$(mktemp /tmp/xo1-browse-live.XXXXXX)
  "$BROWSE" >"$LOG" 2>&1 &
  LAUNCH_PID=$!
  sleep 5

  if kill -0 "$LAUNCH_PID" 2>/dev/null; then
    pass "live Browse launch stayed running for 5s (pid $LAUNCH_PID)"
    if pgrep -f 'xulrunner|WebActivity|Browse\.activity' >/dev/null 2>&1; then
      pass "live Browse launch started xulrunner/Browse process"
    else
      fail "live Browse launch running but no xulrunner/Browse process found"
    fi
    kill "$LAUNCH_PID" 2>/dev/null || true
    wait "$LAUNCH_PID" 2>/dev/null || true
  else
    wait "$LAUNCH_PID" 2>/dev/null || true
    if grep -qi 'traceback\|dbus\.exceptions' "$LOG"; then
      fail "live Browse launch crashed with traceback"
    else
      fail "live Browse launch exited within 5s; log: $(tail -3 "$LOG" | tr '\n' ' ')"
    fi
  fi
  rm -f "$LOG"
fi

echo
echo "==> Results: pass=$PASS fail=$FAIL skip=$SKIP"
if [ "$FAIL" -eq 0 ]; then
  echo "ACCEPTED"
  exit 0
fi
echo "REJECTED"
exit 1
