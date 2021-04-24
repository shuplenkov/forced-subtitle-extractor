FROM alpine:3.12 AS builder
ARG FFMPEG_VERSION=4.3

WORKDIR /builder

RUN apk add --no-cache --update\
  build-base coreutils gcc pkgconfig yasm wget \
  libass-dev \
  bzip2-static libpng-static zlib-static \
  expat-static graphite2-static brotli-static \
  freetype-static fribidi-static fontconfig-static

#Workaround pkg-config not finding libass dependencies, since brotli-static has a different name than brotli.
RUN ln -s /usr/lib/libbrotlicommon-static.a /usr/lib/libbrotlicommon.a && \
    ln -s /usr/lib/libbrotlidec-static.a /usr/lib/libbrotlidec.a


RUN wget -q -O source_ffmpeg.tar.bz2 "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2" && \
  tar xjf source_ffmpeg.tar.bz2 &&\
  cd ffmpeg* && mkdir -p "/ffmpeg_bins" && \
  PATH="/ffmpeg_bins:$PATH" ./configure \
    --pkg-config-flags="--static" \
    --prefix="ffmpeg_min_build" \
    --bindir="/ffmpeg_bins" \
    --extra-ldflags="-static" \
    --extra-libs="-lpthread -lm" \
    # Considering we did not "--enable-non-free",
    # static binaries should be okay to be in the distributed docker image regarding licences.
    --enable-gpl \
    --enable-static \
    --disable-shared \
    --enable-small \
    --disable-doc \
    --disable-debug \
    --disable-ffplay \
    --disable-network \
    --disable-devices \
    --disable-avdevice \
    --disable-avresample \
    --disable-swresample \
    --disable-swscale \
    --disable-decoders \
    --disable-encoders \
    --disable-muxers \
    --disable-filters \
    --disable-postproc \
    --disable-bsfs \
    --disable-protocols \
    --enable-libass \
    --enable-protocol="file" \
    --enable-decoder="ssa,ass,dvbsub,dvdsub,cc_dec,pgssub,jacosub,microdvd,mov_text,mpl2,pjs,realtext,sami,stl,srt,subrip,subviewer,subviewer1,text,vplayer,webvtt,xsub" \
    --enable-encoder="ssa,ass,dvbsub,dvdsub,mov_text,srt,subrip,text,webvtt,xsub" \
    --enable-muxer="ass,jacosub,microdvd,srt,sup,webvtt"\
    --extra-version="minimal-subtitles" \
    || (cat ffbuild/config.log ; false) &&\
  PATH="/ffmpeg_bins:$PATH" make && \
  make install &&\
  cd .. && rm -rf *


FROM alpine:3.12

RUN apk add -q --no-cache bash npm

COPY --from=builder "/ffmpeg_bins" "/usr/bin/"
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
