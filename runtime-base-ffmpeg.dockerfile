# syntax=docker/dockerfile:1

ARG FFMPEG_IMAGE=ghcr.io/modoforge/ffmpeg:6.1.6
ARG BASE_IMAGE=python:3.12-slim-bookworm

FROM ${FFMPEG_IMAGE} AS ffmpeg

FROM ${BASE_IMAGE}

ARG FFMPEG_IMAGE
ARG LIBSNDFILE_PACKAGE_VERSION
ARG LIBSNDFILE_VERSION

LABEL io.modoforge.runtime-base.ffmpeg.image="${FFMPEG_IMAGE}" \
      io.modoforge.runtime-base.ffmpeg.variant="full-gpl" \
      io.modoforge.runtime-base.libsndfile.version="${LIBSNDFILE_VERSION}"

ENV PATH="/opt/ffmpeg/bin:${PATH}" \
      LD_LIBRARY_PATH="/opt/ffmpeg/lib"

COPY --from=ffmpeg /opt/ffmpeg /opt/ffmpeg

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
      set -eu; \
      rm -f /etc/apt/apt.conf.d/docker-clean; \
      apt-get -o Acquire::Retries=5 update; \
      attempt=1; \
      while ! apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
            fonts-dejavu-core \
            frei0r-plugins \
            libaom3 \
            libasound2 \
            libass9 \
            libavc1394-0 \
            libbluray2 \
            libbs2b0 \
            libcaca0 \
            libcdio-paranoia2 \
            libchromaprint1 \
            libcodec2-1.0 \
            libdav1d6 \
            libdc1394-25 \
            libdrm2 \
            libflite1 \
            libgme0 \
            libgnutls30 \
            libgsm1 \
            libiec61883-0 \
            libjack-jackd2-0 \
            libjxl0.7 \
            libmodplug1 \
            libmp3lame0 \
            libmysofa1 \
            libopenal1 \
            libopenjp2-7 \
            libopenmpt0 \
            libopencore-amrnb0 \
            libopencore-amrwb0 \
            libopus0 \
            libpulse0 \
            librav1e0 \
            librist4 \
            librtmp1 \
            librubberband2 \
            libshine3 \
            "libsndfile1=${LIBSNDFILE_PACKAGE_VERSION}" \
            libsmbclient \
            libsnappy1v5 \
            libsoxr0 \
            libspeex1 \
            libsrt1.5-openssl \
            libssh-4 \
            libsvtav1enc1 \
            libtheora0 \
            libtwolame0 \
            libv4l-0 \
            libva2 \
            libvdpau1 \
            libvidstab1.1 \
            libvo-amrwbenc0 \
            libvorbisenc2 \
            libvpx7 \
            libvulkan1 \
            libwebp7 \
            libwebpmux3 \
            libx264-164 \
            libx265-199 \
            libxcb-shape0 \
            libxcb-shm0 \
            libxcb-xfixes0 \
            libxml2 \
            libxvidcore4 \
            libzimg2 \
            libzmq5 \
            libzvbi0 \
            ocl-icd-libopencl1; do \
            test "$attempt" -lt 3 || exit 1; \
            attempt=$((attempt + 1)); \
            apt-get -o Acquire::Retries=5 update; \
      done; \
      rm -rf /var/lib/apt/lists/*; \
      ffmpeg -version; \
      ffprobe -version; \
      for encoder in libsvtav1 libvpx-vp9 libx264 libx265; do \
            ffmpeg -hide_banner -h "encoder=${encoder}" 2>&1 \
                  | grep -Fq "Encoder ${encoder}" || exit 1; \
      done; \
      for filter in ass loudnorm subtitles zscale; do \
            ffmpeg -hide_banner -h "filter=${filter}" 2>&1 \
                  | grep -Fq "Filter ${filter}" || exit 1; \
    done
