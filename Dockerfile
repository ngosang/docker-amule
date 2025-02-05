FROM alpine:edge AS builder

WORKDIR /tmp

# Install aMule
RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing amule amule-doc

# Install a modern Web UI
RUN AMULEWEBUI_RELOADED_COMMIT=7c708c9ed95e5298fd45fea232a9341643eb7c66 && \
    cd /usr/share/amule/webserver && \
    wget -O AmuleWebUI-Reloaded.zip https://github.com/MatteoRagni/AmuleWebUI-Reloaded/archive/${AMULEWEBUI_RELOADED_COMMIT}.zip && \
    unzip AmuleWebUI-Reloaded.zip && \
    mv AmuleWebUI-Reloaded-* AmuleWebUI-Reloaded && \
    rm -rf AmuleWebUI-Reloaded.zip AmuleWebUI-Reloaded/doc-images AmuleWebUI-Reloaded/README.md

FROM alpine:edge

LABEL maintainer="ngosang@hotmail.es"

# Install packages
RUN apk add --no-cache libedit libgcc libintl libpng libstdc++ libupnp musl wxwidgets zlib tzdata pwgen mandoc curl && \
    apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing crypto++

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

# Add entrypoint
COPY entrypoint.sh /home/amule/entrypoint.sh

WORKDIR /home/amule

EXPOSE 4711/tcp 4712/tcp 4662/tcp 4665/udp 4672/udp

ENTRYPOINT ["/home/amule/entrypoint.sh"]

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
