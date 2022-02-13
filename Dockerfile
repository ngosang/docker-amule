FROM alpine:edge as builder

WORKDIR /tmp

# Install aMule
RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing amule

# Install a modern Web UI
RUN cd /usr/share/amule/webserver && \
    wget -O AmuleWebUI-Reloaded.zip https://github.com/MatteoRagni/AmuleWebUI-Reloaded/archive/refs/heads/master.zip && \
    unzip AmuleWebUI-Reloaded.zip && \
    mv AmuleWebUI-Reloaded-master AmuleWebUI-Reloaded && \
    rm -rf AmuleWebUI-Reloaded.zip AmuleWebUI-Reloaded/doc-images

FROM alpine:edge

LABEL maintainer="ngosang@hotmail.es"

# Install packages
RUN apk --no-cache add libgcc libpng libstdc++ libupnp libintl musl zlib wxgtk-base tzdata pwgen sudo && \
    apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing crypto++

# Copy binaries
COPY --from=builder /usr/bin/alcc /usr/bin/amulecmd /usr/bin/amuled /usr/bin/amuleweb /usr/bin/ed2k /usr/bin/
COPY --from=builder /usr/share/amule /usr/share/amule

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
# => Reference Alpine packages
# https://git.alpinelinux.org/aports/tree/testing/amule
