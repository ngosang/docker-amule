FROM alpine:edge as builder
ARG TARGETPLATFORM
RUN echo "I'm building for $TARGETPLATFORM"

WORKDIR /tmp

# Older version of automake required for R package httpuv
RUN echo 'http://dl-cdn.alpinelinux.org/alpine/v3.11/main' >> /etc/apk/repositories

# Download R and system dependencies
RUN set -ex; \
    apk add --no-cache \
	autoconf=2.69-r2 \
	automake=1.16.1-r0 

# Install aMule
#RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing amule amule-doc
ENV AMULE_VERSION 2.3.2
ENV UPNP_VERSION 1.14.13
ENV CRYPTOPP_VERSION CRYPTOPP_5_6_5
ENV BOOST_VERSION=1.80.0
ENV BOOST_VERSION_=1_80_0
ENV BOOST_ROOT=/usr/include/boost


# Upgrade required packages (build)
RUN apk --update add gd geoip libpng libwebp pwgen sudo wxgtk zlib bash && \
    apk --update add --virtual build-dependencies alpine-sdk \
                               bison g++ gcc gd-dev geoip-dev \
                               gettext gettext-dev git libpng-dev libwebp-dev \
                               libtool libsm-dev make musl-dev wget \
                               wxgtk3-dev zlib-dev 
							   

# Get boost headers
RUN mkdir -p ${BOOST_ROOT} \
    && wget "https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_}.tar.gz" \
    && tar zxf boost_${BOOST_VERSION_}.tar.gz -C ${BOOST_ROOT} --strip-components=1

# Build libupnp
RUN mkdir -p /build \
    && wget "http://downloads.sourceforge.net/sourceforge/pupnp/libupnp-${UPNP_VERSION}.tar.bz2" \
    && tar xfj libupnp*.tar.bz2 \
    && cd libupnp* \
    && ./configure --prefix=/usr >/dev/null \
    && make -j$(nproc) >/dev/null \
    && make install \
    && make DESTDIR=/build install

# Build crypto++
RUN mkdir -p /build \
    && git clone --branch master --single-branch "https://github.com/weidai11/cryptopp"  \
    && cd cryptopp* \
    && make CXXFLAGS="${CXXFLAGS} -DNDEBUG -fPIC" -j$(nproc) -f GNUmakefile dynamic >/dev/null \
    && make PREFIX="/usr" install \
    && make DESTDIR=/build PREFIX="/usr" install

# Build amule from source
ADD "https://api.github.com/repos/mercu01/amule/commits?per_page=1" latest_commit
RUN mkdir -p /build \
    && git clone --branch 2.3.3_Broadband --single-branch "https://github.com/mercu01/amule" \
    && cd amule* \
    && ./autogen.sh >/dev/null \
    && ./configure \
		--build=$(uname -m) \
        --prefix=/usr \
        --mandir=/usr/share/man \
        --enable-alc \
 		--enable-alcc \
 		--enable-amule-daemon \
 		--enable-amule-gui \
 		--enable-amulecmd \
 		--enable-ccache \
 		--enable-geoip \
 		--enable-optimize \
 		--enable-upnp \
 		--enable-webserver \
 		--disable-debug \
        --with-boost=${BOOST_ROOT} \
		--with-wx-config=wx-config-gtk3 \
        >/dev/null  \
    && make -j$(nproc) >/dev/null \
    && make DESTDIR=/build install 

# Install a modern Web UI
RUN cd /build/usr/share/amule/webserver && \
    wget -O AmuleWebUI-Reloaded.zip https://github.com/MatteoRagni/AmuleWebUI-Reloaded/archive/refs/heads/master.zip && \
    unzip AmuleWebUI-Reloaded.zip && \
    mv AmuleWebUI-Reloaded-master AmuleWebUI-Reloaded && \
    rm -rf AmuleWebUI-Reloaded.zip AmuleWebUI-Reloaded/doc-images

FROM alpine:edge

LABEL maintainer="mercu01@gmail.com original author -> ngosang@hotmail.es"

# Install packages
RUN apk add --no-cache libgcc libpng libstdc++ libupnp libintl musl zlib wxgtk-base tzdata pwgen mandoc curl && \
    apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing crypto++

# Copy build directory
COPY --from=builder /build/usr/bin/alcc /usr/bin/alcc
COPY --from=builder /build/usr/bin/amulecmd /usr/bin/amulecmd
COPY --from=builder /build/usr/bin/amuled /usr/bin/amuled
COPY --from=builder /build/usr/bin/amuleweb /usr/bin/amuleweb
COPY --from=builder /build/usr/bin/ed2k /usr/bin/ed2k
COPY --from=builder /build/usr/share/amule /usr/share/amule

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

ENTRYPOINT ["sh", "/home/amule/entrypoint.sh"]

# HELP
#
# => Build Docker image
#docker buildx build --platform linux/arm64/v8 -t mercu/builder-amule:arm64 .
# => Push Dockerhub image
#docker push mercu/builder-amule:arm64