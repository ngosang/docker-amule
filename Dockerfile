FROM alpine:edge as builder

WORKDIR /tmp

# Install aMule
#RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing amule amule-doc
ENV AMULE_VERSION 2.3.2
ENV UPNP_VERSION 1.6.22
ENV CRYPTOPP_VERSION CRYPTOPP_5_6_5
ENV BOOST_VERSION=1.76.0
ENV BOOST_VERSION_=1_76_0
ENV BOOST_ROOT=/usr/include/boost

WORKDIR /tmp

# Upgrade required packages (build)
RUN apk --update add gd geoip libpng libwebp pwgen sudo wxgtk zlib bash && \
    apk --update add --virtual build-dependencies alpine-sdk automake \
                               autoconf bison g++ gcc gd-dev geoip-dev \
                               gettext gettext-dev git libpng-dev libwebp-dev \
                               libtool libsm-dev make musl-dev wget \
                               wxgtk-dev zlib-dev 
							   

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
    && git clone --branch master --single-branch "https://github.com/mercu01/amule" \
    && cd amule* \
    && ./autogen.sh >/dev/null \
    && ./configure \
        --disable-gui \
        --disable-amule-gui \
        --disable-wxcas \
        --disable-alc \
        --disable-plasmamule \
        --disable-kde-in-home \
        --prefix=/usr \
        --mandir=/usr/share/man \
        --enable-unicode \
        --without-subdirs \
        --without-expat \
        --enable-amule-daemon \
        --enable-amulecmd \
        --enable-webserver \
        --enable-cas \
        --enable-alcc \
        --enable-fileview \
        --enable-geoip \
        --enable-mmap \
        --enable-optimize \
        --enable-upnp \
        --disable-debug \
        --with-boost=${BOOST_ROOT} \
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
COPY --from=builder /build /

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
# docker build -t mercu/ngosang/builder-amule:latest .
#
# => Reference Alpine packages
# https://git.alpinelinux.org/aports/tree/testing/amule
