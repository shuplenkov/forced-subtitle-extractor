# bump: alpine /FROM alpine:([\d.]+)/ docker:alpine|^3
# bump: alpine link "Release notes" https://alpinelinux.org/posts/Alpine-$LATEST-released.html
FROM alpine:3.17.3 AS builder

RUN apk add --no-cache \
  coreutils \
  wget \
  rust cargo cargo-c \
  openssl-dev openssl-libs-static \
  ca-certificates \
  bash \
  tar \
  build-base \
  autoconf automake \
  libtool \
  diffutils \
  cmake meson ninja \
  git \
  yasm nasm \
  texinfo \
  jq \
  zlib-dev zlib-static \
  bzip2-dev bzip2-static \
  libxml2-dev libxml2-static \
  expat-dev expat-static \
  fontconfig-dev fontconfig-static \
  freetype freetype-dev freetype-static \
  graphite2-static \
  glib-static \
  tiff tiff-dev \
  libjpeg-turbo libjpeg-turbo-dev \
  libpng-dev libpng-static \
  giflib giflib-dev \
  harfbuzz-dev harfbuzz-static \
  fribidi-dev fribidi-static \
  brotli-dev brotli-static \
  soxr-dev soxr-static \
  lcms2 lcms2-dev \
  tcl \
  numactl-dev \
  cunit cunit-dev \
  fftw-dev \
  libsamplerate-dev libsamplerate-static \
  vo-amrwbenc-dev vo-amrwbenc-static \
  snappy snappy-dev snappy-static \
  xxd \
  xz-dev xz-static

# -O3 makes sure we compile with optimization. setting CFLAGS/CXXFLAGS seems to override
# default automake cflags.
# -static-libgcc is needed to make gcc not include gcc_s as "as-needed" shared library which
# cmake will include as a implicit library.
# other options to get hardened build (same as ffmpeg hardened)
ARG CFLAGS="-O3 -s -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIC"
ARG CXXFLAGS="-O3 -s -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIC"
ARG LDFLAGS="-Wl,-z,relro,-z,now"

# retry dns and some http codes that might be transient errors
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503"

# workaround for https://github.com/pkgconf/pkgconf/issues/268
# link order somehow ends up reversed for libbrotlidec and libbrotlicommon with pkgconf 1.9.4 but not 1.9.3
# adding libbrotlicommon directly to freetype2 required libraries seems to fix it
RUN sed -i 's/libbrotlidec/libbrotlidec, libbrotlicommon/' /usr/lib/pkgconfig/freetype2.pc

# bump: libass /LIBASS_VERSION=([\d.]+)/ https://github.com/libass/libass.git|*
# bump: libass after ./hashupdate Dockerfile LIBASS $LATEST
# bump: libass link "Release notes" https://github.com/libass/libass/releases/tag/$LATEST
ARG LIBASS_VERSION=0.17.1
ARG LIBASS_URL="https://github.com/libass/libass/releases/download/$LIBASS_VERSION/libass-$LIBASS_VERSION.tar.gz"
ARG LIBASS_SHA256=d653be97198a0543c69111122173c41a99e0b91426f9e17f06a858982c2fb03d
RUN \
  wget $WGET_OPTS -O libass.tar.gz "$LIBASS_URL" && \
  echo "$LIBASS_SHA256  libass.tar.gz" | sha256sum --status -c - && \
  tar xf libass.tar.gz && \
  cd libass-* && ./configure --disable-shared --enable-static && \
  make -j$(nproc) && make install

# bump: srt /SRT_VERSION=([\d.]+)/ https://github.com/Haivision/srt.git|^1
# bump: srt after ./hashupdate Dockerfile SRT $LATEST
# bump: srt link "Release notes" https://github.com/Haivision/srt/releases/tag/v$LATEST
ARG SRT_VERSION=1.5.1
ARG SRT_URL="https://github.com/Haivision/srt/archive/v$SRT_VERSION.tar.gz"
ARG SRT_SHA256=af891e7a7ffab61aa76b296982038b3159da690f69ade7c119f445d924b3cf53
RUN \
  wget $WGET_OPTS -O libsrt.tar.gz "$SRT_URL" && \
  echo "$SRT_SHA256  libsrt.tar.gz" | sha256sum --status -c - && \
  tar xf libsrt.tar.gz && cd srt-* && mkdir build && cd build && \
  cmake \
    -G"Unix Makefiles" \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_SHARED=OFF \
    -DENABLE_APPS=OFF \
    -DENABLE_CXX11=ON \
    -DUSE_STATIC_LIBSTDCXX=ON \
    -DOPENSSL_USE_STATIC_LIBS=ON \
    -DENABLE_LOGGING=OFF \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_INCLUDEDIR=include \
    -DCMAKE_INSTALL_BINDIR=bin \
    .. && \
  make -j$(nproc) && make install

# bump: ffmpeg /FFMPEG_VERSION=([\d.]+)/ https://github.com/FFmpeg/FFmpeg.git|^6
# bump: ffmpeg after ./hashupdate Dockerfile FFMPEG $LATEST
# bump: ffmpeg link "Changelog" https://github.com/FFmpeg/FFmpeg/blob/n$LATEST/Changelog
# bump: ffmpeg link "Source diff $CURRENT..$LATEST" https://github.com/FFmpeg/FFmpeg/compare/n$CURRENT..n$LATEST
ARG FFMPEG_VERSION=6.0
ARG FFMPEG_URL="https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.bz2"
ARG FFMPEG_SHA256=47d062731c9f66a78380e35a19aac77cebceccd1c7cc309b9c82343ffc430c3d
# sed changes --toolchain=hardened -pie to -static-pie
# extra ldflags stack-size=2097152 is to increase default stack size from 128KB (musl default) to something
# more similar to glibc (2MB). This fixing segfault with libaom-av1 and libsvtav1 as they seems to pass
# large things on the stack.
RUN \
  wget $WGET_OPTS -O ffmpeg.tar.bz2 "$FFMPEG_URL" && \
  echo "$FFMPEG_SHA256  ffmpeg.tar.bz2" | sha256sum --status -c - && \
  tar xf ffmpeg.tar.bz2 && \
  cd ffmpeg-* && \
  sed -i 's/add_ldexeflags -fPIE -pie/add_ldexeflags -fPIE -static-pie/' configure && \
  ./configure \
  --pkg-config-flags="--static" \
  --extra-cflags="-fopenmp" \
  --extra-ldflags="-fopenmp -Wl,-z,stack-size=2097152" \
  --toolchain=hardened \
  --disable-debug \
  --disable-shared \
  --disable-ffplay \
  --disable-doc \
  --disable-debug \
  --disable-ffplay \
  --disable-network \
  --disable-devices \
  --disable-avdevice \
  --disable-swresample \
  --disable-swscale \
  --disable-decoders \
  --disable-encoders \
  --disable-muxers \
  --disable-filters \
  --disable-postproc \
  --disable-bsfs \
  --disable-protocols \
  --enable-gpl \
  --enable-static \
  --enable-small \
  --enable-libass \
  --enable-protocol="file" \
  --enable-decoder="ssa,ass,dvbsub,dvdsub,cc_dec,pgssub,jacosub,microdvd,mov_text,mpl2,pjs,realtext,sami,stl,srt,subrip,subviewer,subviewer1,text,vplayer,webvtt,xsub" \
  --enable-encoder="ssa,ass,dvbsub,dvdsub,mov_text,srt,subrip,text,webvtt,xsub" \
  --enable-muxer="ass,jacosub,microdvd,srt,sup,webvtt"\
  --extra-version="minimal-subtitles" \
  || (cat ffbuild/config.log ; false) \
  && make -j$(nproc) install

FROM alpine:3.17.3

RUN apk add -q --no-cache bash npm

COPY --from=builder "/usr/local/bin" "/usr/bin/"
#Scripts
COPY "extractForcedSubtitles.sh" "/extractForcedSubtitles.sh"
COPY "start.sh" "/start.sh"
#NodeJS
COPY "package.json" "/package.json"
COPY "package-lock.json" "/package-lock.json"
COPY "server.js" "/server.js"
COPY "pm2.json" "/pm2.json"
#crontabs for root user
COPY "cronjobs" "/etc/crontabs/root"

RUN npm ci --production

ARG NODE_ENV=production
ENV NODE_ENV ${NODE_ENV}

VOLUME "/data"
VOLUME "/db"
WORKDIR "/data"

EXPOSE 3000

ENTRYPOINT ["/start.sh"]
