#!/system/bin/sh
set -eu
[ "$(id -u)" = 0 ] || { echo 'ERROR: Shell Root authorization is required'; exit 1; }
MAGISK_BIN="$(command -v magisk || true)"
if [ -z "$MAGISK_BIN" ]; then
  echo "ERROR: magisk command not found"
  exit 1
fi
"$MAGISK_BIN" --sqlite "REPLACE INTO settings (key,value) VALUES ('zygisk',1);"
value=$("$MAGISK_BIN" --sqlite "SELECT value FROM settings WHERE key='zygisk';")
[ "$value" = 'value=1' ] || { echo 'ERROR: Zygisk setting verification failed'; exit 1; }
echo 'ZYGISK_ENABLED=1'
