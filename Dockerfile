FROM debian:bullseye-20210621-slim
LABEL maintainer="ngosang@hotmail.es"

RUN apt-get update && \
    # Install packages
    apt-get -y install amule-daemon pwgen sudo wget && \
    # Install a nicer Web UI
    cd /usr/share/amule/webserver && \
    wget -O AmuleWebUI-Reloaded.zip https://github.com/MatteoRagni/AmuleWebUI-Reloaded/archive/refs/heads/master.zip && \
    unzip AmuleWebUI-Reloaded.zip && \
    mv AmuleWebUI-Reloaded-master AmuleWebUI-Reloaded && \
    rm -rf AmuleWebUI-Reloaded.zip AmuleWebUI-Reloaded/doc-images && \
    # Clean up
    apt-get -y --purge remove wget && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/log/*

# Fix bug https://github.com/amule-project/amule/issues/265
# grep -rnw '/usr/share/amule/webserver' -e 'amule_stats_kad.png'
RUN sed -i 's/amule_stats_kad.png//g' /usr/share/amule/webserver/default/amuleweb-main-kad.php \
    && sed -i 's/amule_stats_kad.png//g' /usr/share/amule/webserver/AmuleWebUI-Reloaded/amuleweb-main-kad.php \
    && sed -i 's/amule_stats_kad.png//g' /usr/share/amule/webserver/AmuleWebUI-Reloaded/amuleweb-main-stats.php

# Add entrypoint
ADD amule-entrypoint.sh /home/amule/amule-entrypoint.sh
RUN chmod a+x /home/amule/amule-entrypoint.sh

EXPOSE 4711/tcp 4712/tcp 4662/tcp 4665/udp 4672/udp

ENTRYPOINT ["/home/amule/amule-entrypoint.sh"]

# HELP
# docker build -t ngosang/amule:2.3.3-2 --platform linux/amd64 .
