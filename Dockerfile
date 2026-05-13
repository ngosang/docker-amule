FROM alpine:3.23 AS builder

WORKDIR /tmp

# Install build tools
RUN apk add --no-cache \
        gcc g++ make curl git \
        boost-dev crypto++-dev geoip-dev libupnp-dev readline-dev wxwidgets-dev zlib-dev

# Build aMule from source
ENV AMULE_VERSION=2.3.3
RUN curl -fL "https://downloads.sourceforge.net/project/amule/aMule/${AMULE_VERSION}/aMule-${AMULE_VERSION}.tar.gz" -o amule.tar.gz && \
    tar -xf amule.tar.gz && \
    sed -i '1s/^/#include <exception>\n/' aMule-${AMULE_VERSION}/src/libs/common/MuleDebug.cpp && \
    cd aMule-${AMULE_VERSION} && \
    ./configure \
        CXXFLAGS="-O2" \
        CFLAGS="-O2" \
        --prefix=/usr \
        --mandir=/usr/share/man \
        --enable-alcc \
        --enable-amule-daemon \
        --enable-amulecmd \
        --enable-geoip \
        --enable-optimize \
        --enable-upnp \
        --enable-webserver \
        --disable-debug \
        --disable-nls \
        --disable-monolithic \
        --with-boost && \
    make -j"$(nproc)" && \
    make install && \
    strip -s /usr/bin/alcc /usr/bin/amulecmd /usr/bin/amuled /usr/bin/amuleweb /usr/bin/ed2k && \
    mkdir -p /usr/share/man/man1 && \
    install -m644 docs/man/amulecmd.1 docs/man/amuled.1 docs/man/amuleweb.1 docs/man/ed2k.1 /usr/share/man/man1/ && \
    gzip /usr/share/man/man1/amulecmd.1 /usr/share/man/man1/amuled.1 \
        /usr/share/man/man1/amuleweb.1 /usr/share/man/man1/ed2k.1 && \
    rm -rf /tmp/*

# Download alternative Web UI
ENV AMULEWEBUI_RELOADED_COMMIT=3fef80d724b71366667d7ae9de5809b878b98f75
RUN cd /usr/share/amule/webserver && \
    git clone https://github.com/MatteoRagni/AmuleWebUI-Reloaded.git AmuleWebUI-Reloaded && \
    git -C AmuleWebUI-Reloaded checkout ${AMULEWEBUI_RELOADED_COMMIT} && \
    rm -rf AmuleWebUI-Reloaded/.git AmuleWebUI-Reloaded/doc-images AmuleWebUI-Reloaded/LICENSE AmuleWebUI-Reloaded/README.md

FROM alpine:3.23

LABEL maintainer="ngosang@hotmail.es"

# Copy binaries, Web UI and man docs
COPY --from=builder /usr/bin/alcc /usr/bin/amulecmd /usr/bin/amuled /usr/bin/amuleweb /usr/bin/ed2k /usr/bin/
COPY --from=builder /usr/share/amule /usr/share/amule
COPY --from=builder /usr/share/man/man1/amulecmd.1.gz /usr/share/man/man1/amuled.1.gz \
    /usr/share/man/man1/amuleweb.1.gz /usr/share/man/man1/ed2k.1.gz /usr/share/man/man1/

# Install runtime dependencies and remove unnecessary locale files
RUN apk add --no-cache \
        crypto++ readline libgcc libstdc++ geoip libupnp libpng wxwidgets tzdata pwgen curl mandoc \
        s6 execline su-exec && \
    rm -rf /usr/share/locale && \
    # Check binaries are OK
    ldd /usr/bin/alcc > /dev/null && \
    ldd /usr/bin/amulecmd > /dev/null && \
    ldd /usr/bin/amuled > /dev/null && \
    ldd /usr/bin/amuleweb > /dev/null && \
    ldd /usr/bin/ed2k > /dev/null && \
    # Check man documentation is OK
    man amulecmd > /dev/null && \
    man amuled > /dev/null && \
    man amuleweb > /dev/null && \
    man ed2k > /dev/null

# Add entrypoint and S6 services
COPY --chmod=755 docker/entrypoint.sh docker/amule-config.sh docker/amule-mods.sh /home/amule/
COPY --chmod=755 docker/services.d/ /etc/services.d/

WORKDIR /home/amule

EXPOSE 4711/tcp 4712/tcp 4662/tcp 4665/udp 4672/udp

ENTRYPOINT ["/home/amule/entrypoint.sh"]

# HELP
#
# => Build Docker image
# docker build -t ngosang/amule:test --progress=plain .
#
# => Build multi-arch Docker image
# docker buildx create --use
# docker buildx build -t ngosang/amule:test --progress=plain --platform linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/riscv64,linux/s390x .
