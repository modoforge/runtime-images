# syntax=docker/dockerfile:1

# BuildKit selects the target-platform Debian stage. Native compilation keeps
# FFmpeg's architecture-specific assembly selection under upstream configure.
FROM debian:bookworm-slim AS builder

ENV FFMPEG_VERSION=6.1.6 \
     FFMPEG_SOURCE_SHA256=d4fcb164028dd3beee5d92c0ac72e46aac6973c75ea12dc14de07bf8f407370a
ARG NV_CODEC_HEADERS_VERSION=12.1.14.0
ARG NV_CODEC_HEADERS_SHA256=2fefaa227d2a3b4170797796425a59d1dd2ed5fd231db9b4244468ba327acd0b
ARG VULKAN_HEADERS_VERSION=1.3.275
ARG VULKAN_HEADERS_SHA256=7161da645dbd33fd4ea61eec08e0d77389a640010acbf4afc00234f84df9b314

# Install the codec, filter, protocol, and hardware-API development surface used
# by the published FFmpeg-PyTorch runtime bases. Vendor drivers remain host-provided.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
     set -eu; \
     rm -f /etc/apt/apt.conf.d/docker-clean; \
     apt-get -o Acquire::Retries=5 update; \
     attempt=1; \
     while ! apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
          build-essential \
          ca-certificates \
          curl \
          flite1-dev \
          frei0r-plugins-dev \
          ladspa-sdk \
          libaom-dev \
          libasound2-dev \
          libass-dev \
          libavc1394-dev \
          libbluray-dev \
          libbs2b-dev \
          libcaca-dev \
          libcdio-paranoia-dev \
          libchromaprint-dev \
          libcodec2-dev \
          libdav1d-dev \
          libdc1394-dev \
          libdrm-dev \
          libfontconfig1-dev \
          libfreetype6-dev \
          libfribidi-dev \
          libgme-dev \
          libgnutls28-dev \
          libgsm1-dev \
          libharfbuzz-dev \
          libiec61883-dev \
          libjack-jackd2-dev \
          libjxl-dev \
          libmodplug-dev \
          libmp3lame-dev \
          libmysofa-dev \
          libopenal-dev \
          libopenjp2-7-dev \
          libopenmpt-dev \
          libopencore-amrnb-dev \
          libopencore-amrwb-dev \
          libopus-dev \
          libpulse-dev \
          librav1e-dev \
          librist-dev \
          librtmp-dev \
          librubberband-dev \
          libshine-dev \
          libsmbclient-dev \
          libsnappy-dev \
          libsoxr-dev \
          libspeex-dev \
          libsrt-openssl-dev \
          libssh-dev \
          libsvtav1enc-dev \
          libtheora-dev \
          libtwolame-dev \
          libv4l-dev \
          libva-dev \
          libvdpau-dev \
          libvidstab-dev \
          libvo-amrwbenc-dev \
          libvorbis-dev \
          libvpx-dev \
          libvulkan-dev \
          libwebp-dev \
          libx264-dev \
          libx265-dev \
          libxcb-shape0-dev \
          libxcb-shm0-dev \
          libxcb-xfixes0-dev \
          libxml2-dev \
          libxvidcore-dev \
          libzimg-dev \
          libzmq3-dev \
          libzvbi-dev \
          nasm \
          ocl-icd-opencl-dev \
          pkg-config \
          xz-utils; do \
          test "$attempt" -lt 3 || exit 1; \
          attempt=$((attempt + 1)); \
          apt-get -o Acquire::Retries=5 update; \
     done; \
     rm -rf /var/lib/apt/lists/*

# Bookworm ships nv-codec-headers 11.1, while FFmpeg 6.1 requires the 12.x
# NVENC/NVDEC API. Headers only define the interface; vendor drivers remain
# host-provided at runtime.
RUN curl --fail --location --retry 3 \
      "https://github.com/FFmpeg/nv-codec-headers/archive/refs/tags/n${NV_CODEC_HEADERS_VERSION}.tar.gz" \
      --output /tmp/nv-codec-headers.tar.gz \
 && echo "${NV_CODEC_HEADERS_SHA256}  /tmp/nv-codec-headers.tar.gz" \
      | sha256sum --check - \
 && mkdir /tmp/nv-codec-headers \
 && tar --extract --gzip --file /tmp/nv-codec-headers.tar.gz \
      --directory /tmp/nv-codec-headers --strip-components=1 \
 && make -C /tmp/nv-codec-headers PREFIX=/usr install \
 && rm -rf /tmp/nv-codec-headers /tmp/nv-codec-headers.tar.gz

# FFmpeg 6.1 requires Vulkan headers >= 1.3.255; Bookworm provides 1.3.239.
# The newer headers remain compatible with Bookworm's Vulkan loader ABI.
RUN curl --fail --location --retry 3 \
      "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/v${VULKAN_HEADERS_VERSION}.tar.gz" \
      --output /tmp/vulkan-headers.tar.gz \
 && echo "${VULKAN_HEADERS_SHA256}  /tmp/vulkan-headers.tar.gz" \
      | sha256sum --check - \
 && mkdir /tmp/vulkan-headers \
 && tar --extract --gzip --file /tmp/vulkan-headers.tar.gz \
      --directory /tmp/vulkan-headers --strip-components=1 \
 && cp -R /tmp/vulkan-headers/include/. /usr/local/include/ \
 && rm -rf /tmp/vulkan-headers /tmp/vulkan-headers.tar.gz

# Download, verify, and unpack the pinned upstream source.
RUN curl --fail --location --retry 3 \
      "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" \
      --output /tmp/ffmpeg.tar.xz \
 && echo "${FFMPEG_SOURCE_SHA256}  /tmp/ffmpeg.tar.xz" | sha256sum --check - \
 && mkdir /tmp/ffmpeg \
 && tar --extract --xz --file /tmp/ffmpeg.tar.xz \
      --directory /tmp/ffmpeg --strip-components=1 \
 && rm /tmp/ffmpeg.tar.xz

WORKDIR /tmp/ffmpeg

# Keep the runtime payload shared while enabling the broadest redistributable
# feature set available from Debian Bookworm. GPL/version-3 are deliberate:
# they are required by x264/x265 and several high-quality filters/codecs.
RUN ./configure \
       --prefix=/opt/ffmpeg \
       --disable-debug \
       --disable-doc \
       --disable-ffplay \
       --disable-static \
       --enable-shared \
       --enable-gpl \
       --enable-version3 \
       --enable-alsa \
       --enable-frei0r \
       --enable-gnutls \
       --enable-ladspa \
       --enable-libaom \
       --enable-libass \
       --enable-libbluray \
       --enable-libbs2b \
       --enable-libcaca \
       --enable-libcdio \
       --enable-chromaprint \
       --enable-libcodec2 \
       --enable-libdav1d \
       --enable-libdc1394 \
       --enable-libdrm \
       --enable-libflite \
       --enable-libfontconfig \
       --enable-libfreetype \
       --enable-libfribidi \
       --enable-libgme \
       --enable-libgsm \
       --enable-libharfbuzz \
       --enable-libiec61883 \
       --enable-libjack \
       --enable-libjxl \
       --enable-libmodplug \
       --enable-libmp3lame \
       --enable-libmysofa \
       --enable-libopenjpeg \
       --enable-libopenmpt \
       --enable-libopencore-amrnb \
       --enable-libopencore-amrwb \
       --enable-openal \
       --enable-libopus \
       --enable-libpulse \
       --enable-librav1e \
       --enable-librist \
       --enable-librtmp \
       --enable-librubberband \
       --enable-libshine \
       --enable-libsmbclient \
       --enable-libsnappy \
       --enable-libsoxr \
       --enable-libspeex \
       --enable-libsrt \
       --enable-libssh \
       --enable-libsvtav1 \
       --enable-libtheora \
       --enable-libtwolame \
       --enable-libv4l2 \
       --enable-libvidstab \
       --enable-libvo-amrwbenc \
       --enable-libvorbis \
       --enable-libvpx \
       --enable-libwebp \
       --enable-libx264 \
       --enable-libx265 \
       --enable-libxcb \
       --enable-libxcb-shape \
       --enable-libxcb-shm \
       --enable-libxcb-xfixes \
       --enable-libxml2 \
       --enable-libxvid \
       --enable-libzimg \
       --enable-libzmq \
       --enable-libzvbi \
       --enable-opencl \
       --enable-vaapi \
       --enable-vdpau \
       --enable-vulkan \
       --enable-ffnvcodec \
       --enable-nvdec \
                --enable-nvenc

RUN make -j"$(nproc)"

RUN make install \
 && rm -rf /opt/ffmpeg/include /opt/ffmpeg/lib/pkgconfig /opt/ffmpeg/share

ENV LD_LIBRARY_PATH=/opt/ffmpeg/lib

# Fail the build if a project-critical encoder, decoder, filter, protocol, or
# shared-library ABI disappears because a dependency or configure probe changed.
RUN /opt/ffmpeg/bin/ffmpeg -version \
               | grep -F "ffmpeg version ${FFMPEG_VERSION}" \
 && /opt/ffmpeg/bin/ffprobe -version \
               | grep -F "ffprobe version ${FFMPEG_VERSION}"

RUN for encoder in \
      aac libaom-av1 libmp3lame libopus librav1e libshine libsvtav1 \
      libtheora libtwolame libvorbis libvpx libvpx-vp9 libwebp libx264 \
      libx265 libxvid prores_ks; do \
               echo "checking encoder: ${encoder}"; \
               /opt/ffmpeg/bin/ffmpeg -hide_banner -h "encoder=${encoder}" 2>&1 \
                    | grep -Fq "Encoder ${encoder}" || exit 1; \
          done

RUN for decoder in h264 hevc libaom-av1 libdav1d libvpx-vp9; do \
      echo "checking decoder: ${decoder}"; \
               /opt/ffmpeg/bin/ffmpeg -hide_banner -h "decoder=${decoder}" 2>&1 \
                    | grep -Fq "Decoder ${decoder}" || exit 1; \
          done

RUN for filter in \
      amix ass astats chromakey frei0r loudnorm overlay rubberband scale \
      subtitles tonemap_opencl vidstabdetect vidstabtransform volume \
      volumedetect zscale; do \
               echo "checking filter: ${filter}"; \
               /opt/ffmpeg/bin/ffmpeg -hide_banner -h "filter=${filter}" 2>&1 \
                    | grep -Fq "Filter ${filter}" || exit 1; \
          done

RUN for protocol in https smb rist rtmp srt; do \
      echo "checking protocol: ${protocol}"; \
               /opt/ffmpeg/bin/ffmpeg -hide_banner -protocols 2>&1 \
        | grep -Eq "^[[:space:]]+${protocol}$" || exit 1; \
          done

RUN test -f /opt/ffmpeg/lib/libavcodec.so.60 \
 && test -f /opt/ffmpeg/lib/libavdevice.so.60 \
 && test -f /opt/ffmpeg/lib/libavfilter.so.9 \
 && test -f /opt/ffmpeg/lib/libavformat.so.60 \
 && test -f /opt/ffmpeg/lib/libavutil.so.58 \
 && test -f /opt/ffmpeg/lib/libswresample.so.4 \
 && test -f /opt/ffmpeg/lib/libswscale.so.7

FROM scratch

LABEL io.modoforge.ffmpeg.version="6.1.6" \
     io.modoforge.ffmpeg.variant="full-gpl"

COPY --from=builder /opt/ffmpeg /opt/ffmpeg
