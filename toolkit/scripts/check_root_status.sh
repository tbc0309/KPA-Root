#!/system/bin/sh
echo "ROOT_UID=$(id -u 2>/dev/null)"
if command -v magisk >/dev/null 2>&1; then
  echo "MAGISK_VERSION=$(magisk -v 2>/dev/null | head -n 1)"
  echo "MAGISK_CODE=$(magisk -V 2>/dev/null | head -n 1)"
  zygisk_value=$(magisk --sqlite "SELECT value FROM settings WHERE key='zygisk';" 2>/dev/null | tail -n 1)
  echo "ZYGISK_SETTING=$zygisk_value"
else
  echo "MAGISK_VERSION=not_found"
  echo "MAGISK_CODE=0"
  echo "ZYGISK_SETTING=unknown"
fi
# Zygisk may be injected without a persistent process named zygisk.
zygisk_loaded=0
for zygote_pid in $(pidof zygote64 zygote 2>/dev/null); do
  if grep -q 'libzygisk' "/proc/$zygote_pid/maps" 2>/dev/null; then
    zygisk_loaded=1
    break
  fi
done
if [ "$zygisk_loaded" = 1 ] || ps -A 2>/dev/null | grep -q '[z]ygisk'; then
  echo "ZYGISK_PROCESS=running"
else
  echo "ZYGISK_PROCESS=not_running"
fi
