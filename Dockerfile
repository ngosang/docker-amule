FROM debian:trixie-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /tmp

# Install build tools
# libatomic1: required for 32-bit targets (386, arm/v5, arm/v7)
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake make git binutils-dev ca-certificates pkg-config python3 libatomic1 \
        libboost-dev libcrypto++-dev libmaxminddb-dev libreadline-dev libcurl4-openssl-dev libpcre2-dev zlib1g-dev libpng-dev libupnp-dev \
    && rm -rf /var/lib/apt/lists/*

# wxWidgets is built from source because of a bug in wx: amuled hits a use-after-free in
# the wx event loop during the startup HTTP downloads
# https://github.com/amule-org/amule/issues/1136
# The fix is in wx 3.2.12. Debian trixie is on 3.2.8 and testing/unstable on 3.2.11
# TODO: revert this and install the Debian packages again (libwxgtk3.2-dev at build time,
# libwxbase3.2-1t64 at run time) once wx 3.2.12 is in the Debian repositories
# Only wxBase and wxNet are built, which also drops glib: aMule links it only when wx
# reports __WXGTK__. --with-libcurl is mandatory, aMule's HTTP downloads use wxWebRequest
ARG WX_REF=v3.2.12
RUN git init -q wx-src && \
    git -C wx-src fetch --depth 1 https://github.com/wxWidgets/wxWidgets.git ${WX_REF} && \
    git -C wx-src checkout -q FETCH_HEAD && \
    cd wx-src && \
    ./configure \
        --prefix=/usr \
        --disable-gui \
        --disable-debug \
        --disable-precomp-headers \
        --without-subdirs \
        --without-expat \
        --with-regex=sys \
        --with-zlib=sys \
        --with-libcurl \
        --disable-mimetype \
        --disable-secretstore \
        --disable-debugreport \
        --disable-fs_inet \
        --disable-ftp \
        --disable-sound && \
    make -j"$(nproc)" && \
    make install && \
    strip /usr/lib/libwx_baseu*.so.*.*.* && \
    rm -rf /tmp/*

# Build aMule from source (AMULE_REF can be a tag, branch, or commit SHA)
ARG AMULE_REF=3.2.0
RUN git init -q amule-src && \
    git -C amule-src fetch --depth 1 --tags https://github.com/amule-org/amule.git ${AMULE_REF} && \
    git -C amule-src checkout -q FETCH_HEAD && \
    # libatomic1 only ships libatomic.so.1; find_library(atomic) needs the unversioned symlink
    so="$(find /usr/lib -name 'libatomic.so.1' -print -quit)" && [ -n "$so" ] && ln -sf "$(basename "$so")" "${so%.1}" ; \
    cmake -B amule-build amule-src \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=NO \
        -DBUILD_MONOLITHIC=NO \
        -DBUILD_DAEMON=YES \
        -DBUILD_AMULECMD=YES \
        -DBUILD_WEBSERVER=YES \
        -DBUILD_AMULEAPI=YES \
        -DBUILD_ALCC=YES \
        -DENABLE_IP2COUNTRY=YES \
        -DENABLE_UPNP=YES \
        -DENABLE_NLS=NO && \
    cmake --build amule-build -j"$(nproc)" && \
    cmake --install amule-build && \
    rm -rf /tmp/*

FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

LABEL maintainer="ngosang@hotmail.es"

# Copy binaries and Web UI
COPY --from=builder /usr/bin/alcc /usr/bin/amuleapi /usr/bin/amulecmd /usr/bin/amuled /usr/bin/amuleweb /usr/bin/ed2k /usr/bin/
COPY --from=builder /usr/libexec/amule /usr/libexec/amule
COPY --from=builder /usr/share/amule /usr/share/amule
COPY --from=builder /usr/lib/libwx_baseu*.so.0.*.* /usr/lib/

# Install runtime dependencies and remove unnecessary locale files
RUN apt-get update && apt-get install -y --no-install-recommends \
        libcrypto++8t64 libreadline8t64 libgcc-s1 libstdc++6 libpng16-16t64 libpcre2-32-0 libupnp17t64 libmaxminddb0 \
        libatomic1 libbinutils ca-certificates curl tzdata procps pwgen s6 cron systemd-standalone-sysusers \
    && rm -rf /var/lib/apt/lists/* /usr/share/locale /usr/share/doc/* /usr/share/doc-base /usr/share/lintian && \
    ldconfig && \
    # Check binaries are OK (fail the build if any shared library is missing)
    for bin in /usr/bin/alcc /usr/bin/amuleapi /usr/bin/amulecmd /usr/bin/amuled /usr/bin/amuleweb /usr/bin/ed2k /usr/libexec/amule/amule-media-probe; do \
        if ldd "$bin" | grep -q "not found"; then echo "ERROR: missing shared libraries in $bin:"; ldd "$bin"; exit 1; fi; \
    done

# Use the built-in C.UTF-8 locale so amuled handles non-ASCII paths correctly
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Add entrypoint and S6 services
COPY --chmod=755 docker/entrypoint.sh docker/amule-config.sh docker/amule-mods.sh /home/amule/
COPY --chmod=755 docker/services.d/ /etc/services.d/

WORKDIR /home/amule

EXPOSE 4711/tcp 4712/tcp 4662/tcp 4665/udp 4672/udp

ENTRYPOINT ["/home/amule/entrypoint.sh"]

# HELP
#
# => Build Docker image (stable release, AMULE_REF defaults to the latest stable tag)
# docker build -t ngosang/amule:test --progress=plain .
#
# => Build a develop image from a specific aMule branch or commit
# docker build --build-arg AMULE_REF=<branch-or-commit> -t ngosang/amule:test --progress=plain .
#
# => Build multi-arch Docker image
# docker buildx create --use
# docker buildx build -t ngosang/amule:test --progress=plain --platform linux/386,linux/amd64,linux/arm/v5,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/riscv64,linux/s390x .
