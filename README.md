# ngosang/docker-amule

[aMmule](https://github.com/amule-project/amule) is a multi-platform client for the ED2K file sharing network and based on the windows client eMule. aMule started in August 2003, as a fork of xMule, which is a fork of lMule.

Inspired by [tchabaud](https://github.com/tchabaud/dockerfiles/tree/master/amule) and [synopsis8](https://github.com/synopsis8/dockerfiles/tree/master/amule) work.

## Supported Architectures

The architectures supported by this image are:

| Architecture | Tag |
| :----: | --- |
| x86-64 | amd64-latest |

## Application Setup

The web interface is at: `<your-ip>:4711`

For better download speed you have to open these ports:

* 4662 TCP
* 4665 UDP
* 4672 UDP

## Usage

Here are some example snippets to help you get started creating a container.

### docker-compose

Compatible with docker-compose v2 schemas.

```yaml
---
version: "2.1"
services:
  amule:
    image: ngosang/amule
    container_name: amule
    environment:
      - PUID=0
      - PGID=0
      - TZ=Europe/London
      # GUI_PWD and WEBUI_PWD are only used in initial setup
      - GUI_PWD=<fill_password>
      - WEBUI_PWD=<fill_password>
    ports:
      - "4711:4711" # web ui
      - "4712:4712" # remote gui, webserver, cmd ...
      - "4662:4662" # ed2k tcp
      - "4665:4665/udp" # ed2k global search udp (tcp port +3)
      - "4672:4672/udp" # ed2k udp
    volumes:
      - <fill_amule_configuration_path>:/home/amule/.aMule
      - <fill_amule_completed_downloads_path>:/incoming
      - <fill_amule_incomplete_downloads_path>:/temp
    restart: unless-stopped
```

### docker cli

```bash
docker run -d \
  --name=amule \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -e GUI_PWD=<fill_password> `#optional` \
  -e WEBUI_PWD=<fill_password> `#optional` \
  -p 4711:4711 \
  -p 4712:4712 \
  -p 4662:4662 \
  -p 4665:4665/udp \
  -p 4672:4672/udp \
  -v <fill_amule_configuration_path>:/home/amule/.aMule \
  -v <fill_amule_completed_downloads_path>:/incoming \
  -v <fill_amule_incomplete_downloads_path>:/temp \
  --restart unless-stopped \
  ngosang/amule
```

## Parameters

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Function |
| :----: | --- |
| `-p 4711` | Web UI port. |
| `-p 4712` | Remote gui, webserver, cmd port. |
| `-p 4662` | ED2K TCP port (must be open to Internet). |
| `-p 4665/udp` | ED2K global search UDP port (tcp port +3) (must be open to Internet). |
| `-p 4672/udp` | ED2K UDP port (must be open to Internet). |
| `-e PUID=1000` | for UserID - see below for explanation. |
| `-e PGID=1000` | for GroupID - see below for explanation. |
| `-e TZ=Europe/London` | Specify a timezone to use EG Europe/London. |
| `-e GUI_PWD=<fill_password>` | Set Remote GUI password (only used in initial setup). |
| `-e WEBUI_PWD=<fill_password>` | Set Web UI password (only used in initial setup). |
| `-v /home/amule/.aMule` | Path to save aMule configuration. |
| `-v /incoming` | Path to completed torrents. |
| `-v /temp` | Path to incomplete torrents. |

## User / Group Identifiers

When using volumes (`-v` flags) permissions issues can arise between the host OS and the container, we avoid this issue by allowing you to specify the user `PUID` and group `PGID`.

Ensure any volume directories on the host are owned by the same user you specify and any permissions issues will vanish like magic.

In this instance `PUID=1000` and `PGID=1000`, to find yours use `id user` as below:

```bash
  $ id username
    uid=1000(dockeruser) gid=1000(dockergroup) groups=1000(dockergroup)
```

## Web UI theme

The Docker image includes the classic aMule Web UI and [AmuleWebUI-Reloaded](https://github.com/MatteoRagni/AmuleWebUI-Reloaded) theme.

You can change the theme editing the `amule.conf` file and changing `Template=AmuleWebUI-Reloaded`. Let this option empty to use the default theme.
