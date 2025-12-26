FROM alpine:3.22.2 AS builder

WORKDIR /tmp

# Install aMule
RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing amule amule-doc

# Install a modern Web UI
RUN AMULEWEBUI_RELOADED_COMMIT=704ae1c861561513c010353320bb1ca9f0f2b9fe && \
    cd /usr/share/amule/webserver && \
    wget -O AmuleWebUI-Reloaded.zip https://github.com/MatteoRagni/AmuleWebUI-Reloaded/archive/${AMULEWEBUI_RELOADED_COMMIT}.zip && \
    unzip AmuleWebUI-Reloaded.zip && \
    mv AmuleWebUI-Reloaded-* AmuleWebUI-Reloaded && \
    rm -rf AmuleWebUI-Reloaded.zip AmuleWebUI-Reloaded/doc-images AmuleWebUI-Reloaded/README.md

FROM alpine:3.22.2

LABEL maintainer="ngosang@hotmail.es"

ARG TARGETARCH
ARG S6_OVERLAY_VERSION="3.2.1.0"

# Install packages
RUN apk add --no-cache libedit libgcc libintl libpng libstdc++ libupnp musl wxwidgets zlib tzdata pwgen mandoc curl coreutils xz && \
    apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing crypto++

# Install s6-overlay
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64)   S6_ARCH="x86_64" ;; \
      386)     S6_ARCH="i686" ;; \
      arm)     S6_ARCH="armhf" ;; \
      arm64)   S6_ARCH="aarch64" ;; \
      ppc64)   S6_ARCH="powerpc64" ;; \
      ppc64le) S6_ARCH="powerpc64le" ;; \
      riscv64) S6_ARCH="riscv64" ;; \
      s390x)   S6_ARCH="s390x" ;; \
      *)       echo "Unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    echo "S6_ARCH=${S6_ARCH}"; \
    curl -fsSL -o /tmp/s6-overlay-noarch.tar.xz \
      "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"; \
    curl -fsSL -o /tmp/s6-overlay-${S6_ARCH}.tar.xz \
      "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz"; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz; \
    rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-${S6_ARCH}.tar.xz

# Copy /etc files
COPY etc /etc

# Copy binaries and Man doc
COPY --from=builder /usr/bin/alcc /usr/bin/amulecmd /usr/bin/amuled /usr/bin/amuleweb /usr/bin/ed2k /usr/bin/
COPY --from=builder /usr/share/amule /usr/share/amule
COPY --from=builder /usr/share/man/man1/alcc.1.gz /usr/share/man/man1/amulecmd.1.gz /usr/share/man/man1/amuled.1.gz /usr/share/man/man1/amuleweb.1.gz /usr/share/man/man1/ed2k.1.gz /usr/share/man/man1/

# Check binaries are OK
RUN ldd /usr/bin/alcc && \
    ldd /usr/bin/amulecmd && \
    ldd /usr/bin/amuled && \
    ldd /usr/bin/amuleweb && \
    ldd /usr/bin/ed2k

WORKDIR /home/amule

EXPOSE 4711/tcp 4712/tcp 4662/tcp 4665/udp 4672/udp

ENTRYPOINT ["/init"]

# HELP
#
# => Build Docker image
# docker build -t ngosang/amule:test .
#
# => Build multi-arch Docker image
# docker buildx create --use
# docker buildx build -t ngosang/amule:test --platform linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/riscv64,linux/s390x .
#
# => Reference Alpine packages
# https://git.alpinelinux.org/aports/tree/testing/amule
