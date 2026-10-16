FROM debian:trixie-slim

# Cross-build on an amd64 host; output and private libraries are ARM64.
RUN test "$(dpkg --print-architecture)" = amd64 && \
    dpkg --add-architecture arm64 && \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential pkg-config ca-certificates git cmake \
        gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu \
        qt6-base-dev-tools qt6-declarative-dev-tools \
        qt6-base-dev:arm64 qt6-declarative-dev:arm64 libqt6svg6-dev:arm64 \
        libegl-dev:arm64 libgles-dev:arm64 libgl-dev:arm64 libdrm-dev:arm64 \
        libopus-dev:arm64 libsdl2-dev:arm64 libsdl2-ttf-dev:arm64 libssl-dev:arm64 \
    && rm -rf /var/lib/apt/lists/*

# Moonlight must use private FFmpeg headers and libraries, not Debian FFmpeg.
ENV RK_PREFIX=/opt/moonlight-rk
ENV PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig
ENV PKG_CONFIG_PATH=/opt/moonlight-rk/lib/pkgconfig
ENV LANG=C.UTF-8

ARG MPP_REV=a9380ef333102ac318628f83b5f7a460d377749e
# Rockchip 7.1: libavcodec 61.19.101, libavutil 59.39.100, libswscale 8.3.100.
ARG FFMPEG_REV=a63922000b871c4704fe3391930fc73dfd030677
ARG BUILD_JOBS=2
COPY build-deps.sh /usr/local/bin/build-rk-deps
RUN sh /usr/local/bin/build-rk-deps

COPY build.sh /usr/local/bin/build-moonlight-rk
COPY launch.sh /usr/local/share/moonlight-rk/launch.sh
COPY check-rkmpp.c /usr/local/share/moonlight-rk/check-rkmpp.c
WORKDIR /build
CMD ["sh", "/usr/local/bin/build-moonlight-rk"]
