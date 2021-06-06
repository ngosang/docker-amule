FROM debian:bullseye-20210408-slim
LABEL maintainer="ngosang@hotmail.es"

RUN apt-get update && \
    apt-get -y install amule-daemon git pwgen sudo && \
    apt-get clean

# Install a nicer Web UI
RUN cd /usr/share/amule/webserver \
    && git clone https://github.com/MatteoRagni/AmuleWebUI-Reloaded \
    && rm -rf AmuleWebUI-Reloaded/.git AmuleWebUI-Reloaded/doc-images

# fix bug https://github.com/amule-project/amule/issues/265
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
# docker build -t ngosang/amule:2.3.3-1 --platform linux/amd64 .
