FROM debian:trixie-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /tmp

# Install build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates pkg-config \
        build-essential cmake make git binutils-dev \
        libboost-dev libcrypto++-dev libglib2.0-dev libreadline-dev libwxgtk3.2-dev zlib1g-dev libpng-dev \
    && rm -rf /var/lib/apt/lists/*

# Build aMule from source
ARG AMULE_VERSION=3.0.0
RUN git clone --depth 1 --branch ${AMULE_VERSION} https://github.com/amule-org/amule.git amule-src && \
    cmake -B amule-build amule-src \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_MONOLITHIC=NO \
        -DBUILD_DAEMON=YES \
        -DBUILD_AMULECMD=YES \
        -DBUILD_WEBSERVER=YES \
        -DBUILD_ALCC=YES \
        -DENABLE_IP2COUNTRY=NO \
        -DENABLE_UPNP=NO \
        -DENABLE_NLS=NO && \
    cmake --build amule-build -j"$(nproc)" && \
    cmake --install amule-build && \
    rm -rf /tmp/*

# Download alternative Web UI
ENV AMULEWEBUI_RELOADED_COMMIT=3fef80d724b71366667d7ae9de5809b878b98f75
RUN cd /usr/share/amule/webserver && \
    git init -q AmuleWebUI-Reloaded && \
    git -C AmuleWebUI-Reloaded fetch --depth 1 https://github.com/MatteoRagni/AmuleWebUI-Reloaded.git ${AMULEWEBUI_RELOADED_COMMIT} && \
    git -C AmuleWebUI-Reloaded checkout -q FETCH_HEAD && \
    rm -rf AmuleWebUI-Reloaded/.git AmuleWebUI-Reloaded/doc-images AmuleWebUI-Reloaded/LICENSE AmuleWebUI-Reloaded/README.md

FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

LABEL maintainer="ngosang@hotmail.es"

# Copy binaries and Web UI
COPY --from=builder /usr/bin/alcc /usr/bin/amulecmd /usr/bin/amuled /usr/bin/amuleweb /usr/bin/ed2k /usr/bin/
COPY --from=builder /usr/share/amule /usr/share/amule

# Install runtime dependencies and remove unnecessary locale files
RUN apt-get update && apt-get install -y --no-install-recommends \
        libcrypto++8t64 libreadline8t64 libgcc-s1 libstdc++6 libpng16-16t64 libwxbase3.2-1t64 libglib2.0-0t64 \
        libbinutils \
        tzdata pwgen curl \
        s6 cron systemd-standalone-sysusers \
    && rm -rf /var/lib/apt/lists/* /usr/share/locale /usr/share/doc/* /usr/share/doc-base /usr/share/lintian && \
    # Check binaries are OK (fail the build if any shared library is missing)
    for bin in alcc amulecmd amuled amuleweb ed2k; do \
        if ldd "/usr/bin/$bin" | grep -q "not found"; then echo "ERROR: missing shared libraries in $bin:"; ldd "/usr/bin/$bin"; exit 1; fi; \
    done

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
# docker buildx build -t ngosang/amule:test --progress=plain --platform linux/386,linux/amd64,linux/arm/v5,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/riscv64,linux/s390x .
