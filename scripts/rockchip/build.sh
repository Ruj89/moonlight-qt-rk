#!/bin/sh
set -eu

: "${RK_PREFIX:?}"
BUILD_JOBS=${BUILD_JOBS:-2}
case "$BUILD_JOBS" in ''|0|*[!0-9]*) echo 'BUILD_JOBS must be positive' >&2; exit 1;; esac

# Use a separate directory from the old Debian-FFmpeg build and refuse cached
# qmake results from a previous invocation. No build products go into /src.
build_dir=/build/moonlight-rk-arm64
bundle=/build/moonlight-rk
if [ -e "$build_dir" ] || [ -e "$bundle" ]; then
    echo "Use an empty output directory: $build_dir or $bundle already exists" >&2
    exit 1
fi

for package in libavcodec libavutil libswscale rockchip_mpp; do
    actual_prefix=$(pkg-config --variable=prefix "$package")
    if [ "$actual_prefix" != "$RK_PREFIX" ]; then
        echo "$package resolved to $actual_prefix instead of $RK_PREFIX" >&2
        exit 1
    fi
done

avcodec_version=$(pkg-config --modversion libavcodec)
if [ "$avcodec_version" != 61.19.101 ]; then
    echo "Private libavcodec is $avcodec_version; exactly 61.19.101 is required" >&2
    exit 1
fi

mkdir -p "$build_dir"
cd "$build_dir"
aarch64-linux-gnu-qmake6 -r /src/moonlight-qt.pro -spec linux-aarch64-gnu-g++ \
    'CONFIG+=embedded disable-x11 disable-wayland disable-libva disable-libvdpau disable-libplacebo' \
    "QMAKE_LFLAGS+=-Wl,-rpath-link,$RK_PREFIX/lib"
grep -q -- '-DHAVE_DRM' app/Makefile.Release
grep -q -- '-DHAVE_EGL' app/Makefile.Release
make -j "$BUILD_JOBS" release

mkdir -p "$bundle/bin" "$bundle/lib" "$bundle/share"
cp -a "$RK_PREFIX"/lib/*.so* "$bundle/lib/"
cp -a "$RK_PREFIX/share/build-info" "$RK_PREFIX/share/licenses" "$bundle/share/"
cp app/moonlight "$bundle/bin/moonlight.bin"
cp "$RK_PREFIX/bin/ffmpeg" "$bundle/bin/ffmpeg.bin"

# Enumerate the exact private libavcodec on the target without opening MPP/DRM.
aarch64-linux-gnu-gcc -Wall -Wextra -Werror \
    /usr/local/share/moonlight-rk/check-rkmpp.c \
    $(pkg-config --cflags --libs libavcodec libavutil) \
    -Wl,-rpath-link,"$RK_PREFIX/lib" -ldl -o "$bundle/bin/check-rkmpp.bin"

for program in moonlight-rk ffmpeg-rk check-rkmpp; do
    install -m 755 /usr/local/share/moonlight-rk/launch.sh "$bundle/bin/$program"
done

# Inspect ELF headers without executing ARM64 programs on the build host.
for binary in "$bundle"/bin/*.bin "$bundle"/lib/*.so*; do
    aarch64-linux-gnu-readelf -h "$binary" | grep -q 'Machine:.*AArch64'
done
test -e "$bundle/lib/librockchip_mpp.so"
aarch64-linux-gnu-readelf -d "$bundle/bin/moonlight.bin" > "$bundle/share/build-info/moonlight-needed.txt"
git -c safe.directory=/src -C /src rev-parse HEAD > "$bundle/share/build-info/moonlight-revision"
git -c safe.directory=/src -C /src diff HEAD -- > "$bundle/share/build-info/moonlight.patch"
tar -C /build -czf /build/moonlight-rk-arm64.tar.gz moonlight-rk
printf 'Bundle: /build/moonlight-rk-arm64.tar.gz\n'
