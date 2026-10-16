#!/bin/sh
set -eu

# Invoke these scripts together with bin/*.bin and ../lib/*.so*.
bundle_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
export LD_LIBRARY_PATH="$bundle_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
case "$(basename -- "$0")" in
    moonlight-rk)
        export QT_QPA_PLATFORM=eglfs
        export SDL_VIDEODRIVER=kmsdrm
        # Rockchip vendor kernels may classify NV12-capable Esmart planes as cursors.
        export DRM_ALLOW_CURSOR_PLANE="${DRM_ALLOW_CURSOR_PLANE:-1}"
        # Prefer direct KMS scanout over EGL rendering on the target.
        export GL_IS_SLOW="${GL_IS_SLOW:-1}"
        # Plane known to work for video scanout on the Orange Pi 5 Plus.
        export DRM_VIDEO_PLANE="${DRM_VIDEO_PLANE:-114}"
        # ALSA card 0 is DisplayPort; send audio to the HDMI1 port instead.
        export AUDIODEV="${AUDIODEV:-plughw:CARD=rockchiphdmi1,DEV=0}"
        if [ -z "${QT_QPA_EGLFS_KMS_CONFIG:-}" ]; then
            # Qt only accepts the KMS config as a file. Disable its hardware
            # cursor so it doesn't fight over the cursor plane used for video.
            if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
                kms_config="$XDG_RUNTIME_DIR/moonlight-rk-kms.json"
            else
                kms_config=$(mktemp "${TMPDIR:-/tmp}/moonlight-rk-kms.XXXXXX")
            fi
            printf '{ "hwcursor": false }\n' > "$kms_config"
            export QT_QPA_EGLFS_KMS_CONFIG="$kms_config"
        fi
        exec "$bundle_dir/bin/moonlight.bin" "$@"
        ;;
    ffmpeg-rk) exec "$bundle_dir/bin/ffmpeg.bin" "$@" ;;
    check-rkmpp) exec "$bundle_dir/bin/check-rkmpp.bin" "$@" ;;
    *) echo 'Invoke as moonlight-rk, ffmpeg-rk or check-rkmpp' >&2; exit 1 ;;
esac
