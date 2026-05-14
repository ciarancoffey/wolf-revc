#!/usr/bin/env bash
# Wolf-side startup for reVC. Logs to /assets/wolf-revc-runtime.log so failures
# survive container teardown. Syncs reVC.ini [VideoMode] to gamescope's actual
# size so reVC doesn't bail with "Cannot find desired video mode".
LOG=/assets/wolf-revc-runtime.log
echo "===== $(date -u +%FT%TZ) startup =====" >> "$LOG"
exec >> "$LOG" 2>&1
echo "env: WAYLAND_DISPLAY=$WAYLAND_DISPLAY GAMESCOPE_WIDTH=${GAMESCOPE_WIDTH:-?} GAMESCOPE_HEIGHT=${GAMESCOPE_HEIGHT:-?} GAMESCOPE_REFRESH=${GAMESCOPE_REFRESH:-?}"

if [[ -n "${GAMESCOPE_WIDTH:-}" && -n "${GAMESCOPE_HEIGHT:-}" && -f /assets/reVC.ini ]]; then
    sed -i "/^\[VideoMode\]/,/^\[/ s/^Width=.*/Width=${GAMESCOPE_WIDTH}/"   /assets/reVC.ini
    sed -i "/^\[VideoMode\]/,/^\[/ s/^Height=.*/Height=${GAMESCOPE_HEIGHT}/" /assets/reVC.ini
    echo "synced reVC.ini [VideoMode] to ${GAMESCOPE_WIDTH}x${GAMESCOPE_HEIGHT}"
fi

source /opt/gow/launch-comp.sh
cd /assets
launcher /opt/revc/reVC
echo "----- launcher returned $? at $(date -u +%FT%TZ) -----"
