# Rockchip ARM64 bundle

The `Build` workflow builds this bundle on every push and on pull requests to
`master`, alongside the existing platform builds. `Build - Rockchip ARM64` can
also be run manually from the Actions tab. Download the
`Moonlight-Rockchip-ARM64-<revision>` artifact, which contains a tarball and its
SHA-256 checksum. This does not publish a GitHub Release.

The recipe comes from the locally compiled and container-verified Orange Pi
build. It cross-compiles on amd64 using Debian Trixie, without QEMU or access to
Rockchip hardware. MPP and FFmpeg Rockchip are pinned to full revisions in the
Dockerfile; builds check libavcodec 61.19.101, the H.264/HEVC RKMPP decoder
configuration, Moonlight's DRM/EGL renderers and the AArch64 ELF headers.
GitHub Actions caches the dependency image's layers using the
[Docker GitHub cache backend](https://docs.docker.com/build/ci/github-actions/cache/).

The tarball contains `moonlight-rk/bin`, private FFmpeg/MPP shared libraries in
`moonlight-rk/lib`, licenses, and source revision/build configuration metadata.
Qt6/QML (including EGLFS KMS), SDL2 with KMSDRM, SDL2_ttf, OpenSSL, Opus,
libdrm and working EGL/GLES/GBM drivers must be installed on the ARM64 target.
This bundle targets Armbian/Debian Trixie on Orange Pi 5 Plus / RK3588 with the
vendor kernel; it is not a standalone AppImage or a generic ARM64 package.

## Local build

From the repository root with recursive submodules checked out:

```sh
docker build --platform linux/amd64 --build-arg BUILD_JOBS=2 \
  -t moonlight-rk-arm64-build -f scripts/rockchip/Dockerfile scripts/rockchip
mkdir -p build/rockchip
docker run --rm --platform linux/amd64 \
  --user "$(id -u):$(id -g)" -e BUILD_JOBS=2 \
  -v "$PWD:/src:ro" -v "$PWD/build/rockchip:/build" \
  moonlight-rk-arm64-build
```

Use an empty output directory for each build. Local builds produce
`build/rockchip/moonlight-rk-arm64.tar.gz`; CI adds the revision to the filename.

## Target installation and checks

Verify the downloaded checksum with `sha256sum -c <archive>.sha256`. Extract
the complete archive into `/opt` (move any existing `/opt/moonlight-rk` aside
first to avoid mixing library versions):

```sh
sudo tar -xzf Moonlight-Rockchip-<revision>-arm64.tar.gz -C /opt
/opt/moonlight-rk/bin/check-rkmpp
/opt/moonlight-rk/bin/ffmpeg-rk -hide_banner -decoders | grep rkmpp
/opt/moonlight-rk/bin/moonlight-rk
```

Run Moonlight from a local TTY with access to DRM, input, MPP and DMA heap
devices. The launcher selects Qt EGLFS and SDL KMSDRM, without a compositor.
It scopes `LD_LIBRARY_PATH` to its own process: do not add the private libraries
to the system loader configuration. Debian FFmpeg and Plex remain separate.

The launcher preserves the local build's defaults for the Orange Pi 5 Plus:
`DRM_ALLOW_CURSOR_PLANE=1`, `GL_IS_SLOW=1`, `DRM_VIDEO_PLANE=114`, and HDMI1
ALSA audio via `AUDIODEV=plughw:CARD=rockchiphdmi1,DEV=0`. These values depend
on the target and can be overridden in the environment. Set
`QT_QPA_EGLFS_KMS_CONFIG` to select a different DRM device/configuration.

CI checks compilation and packaging, not hardware behavior. On the target,
test H.264 and HEVC separately, require hardware decoding in Moonlight, and
check for `Using RKMPP decoder on KMSDRM` and `Renderer 'DRM' chosen` in the
logs. Decoder enumeration alone does not prove VPU decoding or DMA-BUF scanout.
4K60, latency, zero-copy operation and repeated stream start/stop still require
hardware validation.
