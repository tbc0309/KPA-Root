#!/system/bin/sh
# Prepare an image only. This script never writes a device partition.
set -eu
cd /data/local/tmp/kpa-auto-patch
chmod 755 busybox magisk magiskboot magiskinit boot_patch.sh
export BOOTMODE=true
export KEEPVERITY=true
export KEEPFORCEENCRYPT=true
export PATCHVBMETAFLAG=false
export RECOVERYMODE=false
export LEGACYSAR=false
export ASH_STANDALONE=1
exec ./busybox sh ./boot_patch.sh ./boot.img
