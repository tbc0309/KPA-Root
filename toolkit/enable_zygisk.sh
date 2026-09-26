#!/system/bin/sh
set -eu
MAGISK_BIN="$(command -v magisk || true)"
if [ -z "$MAGISK_BIN" ]; then
  echo "ERROR: magisk command not found"
  exit 1
fi
"$MAGISK_BIN" --sqlite "REPLACE INTO settings (key,value) VALUES ('zygisk',1);"
echo "Zygisk setting written."

