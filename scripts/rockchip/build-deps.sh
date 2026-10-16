#!/bin/sh
set -eu

: "${RK_PREFIX:?}" "${MPP_REV:?}" "${FFMPEG_REV:?}"
BUILD_JOBS=${BUILD_JOBS:-2}
case "$BUILD_JOBS" in ''|0|*[!0-9]*) echo 'BUILD_JOBS must be positive' >&2; exit 1;; esac

fetch_revision() {
    git init "$2"
    git -C "$2" remote add origin "$1"
    git -C "$2" fetch --depth=1 origin "$3"
    git -C "$2" checkout --detach FETCH_HEAD
    test "$(git -C "$2" rev-parse HEAD)" = "$3"
}

fetch_revision https://github.com/nyanmisaka/ffmpeg-rockchip.git /tmp/rk-ffmpeg "$FFMPEG_REV"
avcodec_major=$(awk '$1 == "#define" && $2 == "LIBAVCODEC_VERSION_MAJOR" {print $3}' /tmp/rk-ffmpeg/libavcodec/version_major.h)
avcodec_minor=$(awk '$1 == "#define" && $2 == "LIBAVCODEC_VERSION_MINOR" {print $3}' /tmp/rk-ffmpeg/libavcodec/version.h)
avcodec_micro=$(awk '$1 == "#define" && $2 == "LIBAVCODEC_VERSION_MICRO" {print $3}' /tmp/rk-ffmpeg/libavcodec/version.h)
avcodec_version="$avcodec_major.$avcodec_minor.$avcodec_micro"
if [ "$avcodec_version" != 61.19.101 ]; then
    echo "FFmpeg source provides libavcodec $avcodec_version; exactly 61.19.101 is required" >&2
    exit 1
fi

fetch_revision https://github.com/nyanmisaka/mpp.git /tmp/rk-mpp "$MPP_REV"
cmake -S /tmp/rk-mpp -B /tmp/rk-mpp-build \
    -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
    -DCMAKE_FIND_ROOT_PATH=/usr/aarch64-linux-gnu \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_INSTALL_PREFIX="$RK_PREFIX" -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DBUILD_TEST=OFF
cmake --build /tmp/rk-mpp-build --parallel "$BUILD_JOBS"
cmake --install /tmp/rk-mpp-build

cd /tmp/rk-ffmpeg
./configure \
    --prefix="$RK_PREFIX" --libdir="$RK_PREFIX/lib" \
    --arch=aarch64 --target-os=linux --enable-cross-compile \
    --cross-prefix=aarch64-linux-gnu- --pkg-config=pkg-config \
    --enable-shared --disable-static --enable-pic \
    --disable-autodetect --disable-doc --disable-debug \
    --disable-ffplay --disable-ffprobe --disable-avdevice --disable-network \
    --enable-gpl --enable-version3 --enable-libdrm --enable-rkmpp \
    --enable-decoder=h264_rkmpp --enable-decoder=hevc_rkmpp \
    --disable-rkrga \
    --extra-ldflags="-Wl,-rpath-link,$RK_PREFIX/lib"

# Fail during image creation rather than silently shipping a software-only build.
grep -q '^#define CONFIG_H264_RKMPP_DECODER 1$' config_components.h
grep -q '^#define CONFIG_HEVC_RKMPP_DECODER 1$' config_components.h
make -j "$BUILD_JOBS"
make install
test "$(pkg-config --modversion libavcodec)" = 61.19.101

mkdir -p "$RK_PREFIX/share/build-info" "$RK_PREFIX/share/licenses/mpp" "$RK_PREFIX/share/licenses/ffmpeg"
printf 'MPP_REV=%s\nFFMPEG_REV=%s\nLIBAVCODEC_VERSION=%s\n' "$MPP_REV" "$FFMPEG_REV" "$avcodec_version" > "$RK_PREFIX/share/build-info/revisions"
cp ffbuild/config.mak "$RK_PREFIX/share/build-info/ffmpeg-config.mak"
cp COPYING* "$RK_PREFIX/share/licenses/ffmpeg/"
cp -a /tmp/rk-mpp/LICENSE* "$RK_PREFIX/share/licenses/mpp/"
rm -rf /tmp/rk-mpp /tmp/rk-mpp-build /tmp/rk-ffmpeg
