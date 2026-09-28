#!/system/bin/sh

set -eu

# Preserve binary patch diagnostics without printing them to the console.
detail_log=/data/local/tmp/kpa_module_install.log
umask 077
: > "$detail_log"
chmod 644 "$detail_log"

install_disabled() {
  module_id="$1"
  archive="$2"

  # Preserve an existing installation and its enabled/disabled state.
  if [ -d "/data/adb/modules/$module_id" ] || [ -d "/data/adb/modules_update/$module_id" ]; then
    echo "MODULE_SKIPPED=$module_id"
    return
  fi

  echo "=== $module_id ===" >> "$detail_log"
  if magisk --install-module "$archive" >> "$detail_log" 2>&1; then
    :
  else
    echo "MODULE_FAILED=$module_id"
    return 1
  fi
  mkdir -p "/data/adb/modules/$module_id"
  touch "/data/adb/modules/$module_id/disable"
  if [ -d "/data/adb/modules_update/$module_id" ]; then
    touch "/data/adb/modules_update/$module_id/disable"
  fi
  echo "MODULE_INSTALLED_DISABLED=$module_id"
}

install_disabled "kpa_myuppy_font" "/data/local/tmp/KPA_MYuppy_Font.zip"
install_disabled "kpa_rgb_control" "/data/local/tmp/KPA_RGB_Control.zip"
install_disabled "playintegrityfix" "/data/local/tmp/PlayIntegrityFork.zip"
install_disabled "zygisk_shamiko" "/data/local/tmp/Shamiko.zip"
install_disabled "DolbyAtmos" "/data/local/tmp/DolbyAtmos_RazerPhone2_v1.0.6_fix.zip"
