#!/usr/bin/env sh

# Exit on error. For debug use set -x
set -e

mod_auto_restart() {
    MOD_AUTO_RESTART_ENABLED=${MOD_AUTO_RESTART_ENABLED:-"false"}
    MOD_AUTO_RESTART_CRON=${MOD_AUTO_RESTART_CRON:-"0 6 * * *"} # every day at 6:00 h
    if [ "${MOD_AUTO_RESTART_ENABLED}" = "true" ]; then
        # Fix bugs https://github.com/ngosang/docker-amule/issues/7
        # Auto restart amuled process. The cron scheduler is configurable.
        printf "[MOD_AUTO_RESTART] aMule will be restarted automatically (cron %s)... You can disable this mod with MOD_AUTO_RESTART_ENABLED=false\n" "$MOD_AUTO_RESTART_CRON"
        # Avoid adding several times the same cron task when the container restarts
        if ! grep -q "MOD_AUTO_RESTART" "/etc/crontabs/root" ; then
            printf "%s /bin/sh -c 'echo \"[MOD_AUTO_RESTART] Restarting aMule...\" && kill \$(pidof amuled)'\n" "$MOD_AUTO_RESTART_CRON" >> /etc/crontabs/root
        fi
        crond -l 8 -f > /dev/stdout 2> /dev/stderr &
    fi
}

mod_fix_kad_graph() {
    MOD_FIX_KAD_GRAPH_ENABLED=${MOD_FIX_KAD_GRAPH_ENABLED:-"false"}
    if [ "${MOD_FIX_KAD_GRAPH_ENABLED}" = "true" ]; then
        # Fix bug https://github.com/amule-project/amule/issues/265
        # Removes the images causing the issue. They won't be visible in the Web UI.
        # grep -rnw '/usr/share/amule/webserver' -e 'amule_stats_kad.png'
        printf "[MOD_FIX_KAD_GRAPH] Removing Kad stats graph to fix potential crash... You can disable this mod with MOD_FIX_KAD_GRAPH_ENABLED=false\n"
        sed -i 's/amule_stats_kad.png//g' /usr/share/amule/webserver/default/amuleweb-main-kad.php
        sed -i 's/amule_stats_kad.png//g' /usr/share/amule/webserver/AmuleWebUI-Reloaded/amuleweb-main-kad.php
        sed -i 's/amule_stats_kad.png//g' /usr/share/amule/webserver/AmuleWebUI-Reloaded/amuleweb-main-stats.php
    fi
}

mod_fix_kad_bootstrap() {
    MOD_FIX_KAD_BOOTSTRAP_ENABLED=${MOD_FIX_KAD_BOOTSTRAP_ENABLED:-"true"}
    if [ "${MOD_FIX_KAD_BOOTSTRAP_ENABLED}" = "true" ]; then
        # Fix bug https://github.com/ngosang/docker-amule/issues/33
        # Download nodes.dat if the file does not exist
        if [ ! -f "${AMULE_HOME}/nodes.dat" ]; then
            printf "[MOD_FIX_KAD_BOOTSTRAP] Downloading nodes.dat from %s ... You can disable this mod with MOD_FIX_KAD_BOOTSTRAP_ENABLED=false\n" "${KAD_NODES_DAT_URL}"
            curl -s -o "${AMULE_HOME}/nodes.dat" "${KAD_NODES_DAT_URL}"
            printf "[MOD_FIX_KAD_BOOTSTRAP] Downloaded successfully!\n"
        else
            printf "[MOD_FIX_KAD_BOOTSTRAP] File nodes.dat already exist. You can disable this mod with MOD_FIX_KAD_BOOTSTRAP_ENABLED=false\n"
        fi
    fi
}

mod_auto_share() {
    MOD_AUTO_SHARE_ENABLED=${MOD_AUTO_SHARE_ENABLED:-"false"}
    MOD_AUTO_SHARE_DIRECTORIES=${MOD_AUTO_SHARE_DIRECTORIES:-"/incoming"}
    if [ "${MOD_AUTO_SHARE_ENABLED}" = "true" ]; then
        # Fix issue https://github.com/ngosang/docker-amule/issues/9
        # Share all the directories (separated by semicolon ';') and subdirectories in aMule.
        printf "[MOD_AUTO_SHARE] Sharing the following directories with sub-directories: %s ... You can disable this mod with MOD_AUTO_SHARE_ENABLED=false\n" "$MOD_AUTO_SHARE_DIRECTORIES"
        SHAREDDIR_CONF=${AMULE_HOME}/shareddir.dat
        printf "/incoming\n" > "$SHAREDDIR_CONF"
        iter=""
        IN="$MOD_AUTO_SHARE_DIRECTORIES"
        while [ "$IN" != "$iter" ] ;do
            iter=${IN%%;*}
            IN="${IN#"$iter";}"
            printf "[MOD_AUTO_SHARE] Sharing directory '%s' with sub-directories...\n" "$iter"
            find "$iter" -type d >> "$SHAREDDIR_CONF"
        done
    fi
}

AMULE_UID=${PUID:-1000}
AMULE_GID=${PGID:-1000}

AMULE_INCOMING=/incoming
AMULE_TEMP=/temp
AMULE_HOME=/home/amule/.aMule
AMULE_CONF=${AMULE_HOME}/amule.conf
REMOTE_CONF=${AMULE_HOME}/remote.conf
KAD_NODES_DAT_URL="http://upd.emule-security.org/nodes.dat"

# Create configuration files if don't exist
AMULE_GROUP="amule"
if grep -q ":${AMULE_GID}:" /etc/group; then
    printf "Group %s already exists. Won't be created.\n" "${AMULE_GID}"
    AMULE_GROUP=$(getent group "${AMULE_GID}" | cut -d: -f1)
    printf "Group %s with GID %s will be used as amule group.\n" "${AMULE_GROUP}" "${AMULE_GID}"
else
    printf "Creating group %s with GID %s ...\n" "${AMULE_GROUP}" "${AMULE_GID}"
    addgroup "${AMULE_GROUP}" -g "${AMULE_GID}"
fi

AMULE_USER="amule"
if grep -q ":${AMULE_UID}:" /etc/passwd; then
    printf "User %s already exists. Won't be added.\n" "${AMULE_UID}"
    AMULE_USER=$(getent passwd "${AMULE_UID}" | cut -d: -f1)
    printf "User %s with UID %s will be used as amule user.\n" "${AMULE_USER}" "${AMULE_UID}"
else
    printf "Creating user %s with UID %s ...\n" "${AMULE_USER}" "${AMULE_UID}"
    adduser "${AMULE_USER}" -u "${AMULE_UID}" -G "${AMULE_GROUP}" -s "/sbin/nologin" -h "/home/amule" -H -D -g "First Last,RoomNumber,WorkPhone,HomePhone"
fi

if [ ! -d "${AMULE_INCOMING}" ]; then
    printf "Directory %s does not exists. Creating ...\n" "${AMULE_INCOMING}"
    mkdir -p "${AMULE_INCOMING}"
fi

if [ ! -d "${AMULE_TEMP}" ]; then
    printf "Directory %s does not exists. Creating ...\n" "${AMULE_TEMP}"
    mkdir -p "${AMULE_TEMP}"
fi

if [ ! -d ${AMULE_HOME} ]; then
    printf "%s directory NOT found. Creating directory ...\n" "${AMULE_HOME}"
    mkdir -p "${AMULE_HOME}"
fi

if [ -z "${GUI_PWD}" ]; then
    AMULE_GUI_PWD=$(pwgen -s 14)
else
    AMULE_GUI_PWD="${GUI_PWD}"
fi
AMULE_GUI_ENCODED_PWD=$(printf "%s" "${AMULE_GUI_PWD}" | md5sum | cut -d ' ' -f 1)

if [ -z "${WEBUI_PWD}" ]; then
    AMULE_WEBUI_PWD=$(pwgen -s 14)
else
    AMULE_WEBUI_PWD="${WEBUI_PWD}"
fi
AMULE_WEBUI_ENCODED_PWD=$(printf "%s" "${AMULE_WEBUI_PWD}" | md5sum | cut -d ' ' -f 1)

if [ ! -f ${AMULE_CONF} ]; then
    printf "Remote GUI password: %s\n" "${AMULE_GUI_PWD}"
    printf "Web UI password: %s\n" "${AMULE_WEBUI_PWD}"

    printf "%s file NOT found. Generating new default configuration ...\n" "${AMULE_CONF}"
    cat > ${AMULE_CONF} <<- EOM
[eMule]
AppVersion=2.3.3
Nick=http://www.aMule.org
QueueSizePref=50
MaxUpload=0
MaxDownload=0
SlotAllocation=50
Port=4662
UDPPort=4672
UDPEnable=1
Address=
Autoconnect=1
MaxSourcesPerFile=300
MaxConnections=500
MaxConnectionsPerFiveSeconds=20
RemoveDeadServer=0
DeadServerRetry=3
ServerKeepAliveTimeout=0
Reconnect=1
Scoresystem=1
Serverlist=0
AddServerListFromServer=0
AddServerListFromClient=0
SafeServerConnect=0
AutoConnectStaticOnly=0
UPnPEnabled=0
UPnPTCPPort=50000
SmartIdCheck=1
ConnectToKad=1
ConnectToED2K=1
TempDir=${AMULE_TEMP}
IncomingDir=${AMULE_INCOMING}
ICH=1
AICHTrust=0
CheckDiskspace=1
MinFreeDiskSpace=1
AddNewFilesPaused=0
PreviewPrio=0
ManualHighPrio=0
StartNextFile=0
StartNextFileSameCat=0
StartNextFileAlpha=0
FileBufferSizePref=1400
DAPPref=1
UAPPref=1
AllocateFullFile=0
OSDirectory=${AMULE_HOME}
OnlineSignature=0
OnlineSignatureUpdate=5
EnableTrayIcon=0
MinToTray=0
ConfirmExit=1
StartupMinimized=0
3DDepth=10
ToolTipDelay=1
ShowOverhead=0
ShowInfoOnCatTabs=1
VerticalToolbar=0
GeoIPEnabled=1
VideoPlayer=
StatGraphsInterval=3
statsInterval=30
DownloadCapacity=300
UploadCapacity=100
StatsAverageMinutes=5
VariousStatisticsMaxValue=100
SeeShare=2
FilterLanIPs=1
ParanoidFiltering=1
IPFilterAutoLoad=1
IPFilterURL=http://upd.emule-security.org/ipfilter.zip
FilterLevel=127
IPFilterSystem=0
FilterMessages=1
FilterAllMessages=0
MessagesFromFriendsOnly=0
MessageFromValidSourcesOnly=1
FilterWordMessages=0
MessageFilter=
ShowMessagesInLog=1
FilterComments=0
CommentFilter=
ShareHiddenFiles=0
AutoSortDownloads=0
NewVersionCheck=0
AdvancedSpamFilter=1
MessageUseCaptchas=1
Language=
SplitterbarPosition=75
YourHostname=
DateTimeFormat=%A, %x, %X
AllcatType=0
ShowAllNotCats=0
SmartIdState=0
DropSlowSources=0
KadNodesUrl=${KAD_NODES_DAT_URL}
Ed2kServersUrl=http://upd.emule-security.org/server.met
ShowRatesOnTitle=0
GeoLiteCountryUpdateUrl=http://mailfud.org/geoip-legacy/GeoIP.dat.gz
StatsServerName=Shorty ED2K stats
StatsServerURL=http://ed2k.shortypower.org/?hash=
CreateSparseFiles=1
[Browser]
OpenPageInTab=1
CustomBrowserString=
[Proxy]
ProxyEnableProxy=0
ProxyType=0
ProxyName=
ProxyPort=1080
ProxyEnablePassword=0
ProxyUser=
ProxyPassword=
[ExternalConnect]
UseSrcSeeds=0
AcceptExternalConnections=1
ECAddress=
ECPort=4712
ECPassword=${AMULE_GUI_ENCODED_PWD}
UPnPECEnabled=0
ShowProgressBar=1
ShowPercent=1
UseSecIdent=1
IpFilterClients=1
IpFilterServers=1
TransmitOnlyUploadingClients=0
[WebServer]
Enabled=1
Password=${AMULE_WEBUI_ENCODED_PWD}
PasswordLow=
Port=4711
WebUPnPTCPPort=50001
UPnPWebServerEnabled=0
UseGzip=1
UseLowRightsUser=0
PageRefreshTime=120
Template=AmuleWebUI-Reloaded
Path=amuleweb
[GUI]
HideOnClose=0
[Razor_Preferences]
FastED2KLinksHandler=1
[SkinGUIOptions]
Skin=
[Statistics]
MaxClientVersions=0
[Obfuscation]
IsClientCryptLayerSupported=1
IsCryptLayerRequested=1
IsClientCryptLayerRequired=1
CryptoPaddingLenght=254
CryptoKadUDPKey=138123518
[PowerManagement]
PreventSleepWhileDownloading=0
[UserEvents]
[UserEvents/DownloadCompleted]
CoreEnabled=0
CoreCommand=
GUIEnabled=0
GUICommand=
[UserEvents/NewChatSession]
CoreEnabled=0
CoreCommand=
GUIEnabled=0
GUICommand=
[UserEvents/OutOfDiskSpace]
CoreEnabled=0
CoreCommand=
GUIEnabled=0
GUICommand=
[UserEvents/ErrorOnCompletion]
CoreEnabled=0
CoreCommand=
GUIEnabled=0
GUICommand=
[HTTPDownload]
URL_1=http://upd.emule-security.org/ipfilter.zip 
EOM
    printf "%s successfullly generated.\n" "${AMULE_CONF}"
else
    printf "%s file found. Using existing configuration.\n" "${AMULE_CONF}"
fi

if [ ! -f ${REMOTE_CONF} ]; then
    printf "Remote GUI password: %s\n" "${AMULE_GUI_PWD}"
    printf "Web UI password: %s\n" "${AMULE_WEBUI_PWD}"

    printf "%s file NOT found. Generating new default configuration ...\n" "${REMOTE_CONF}"
    cat > ${REMOTE_CONF} <<- EOM
Locale=
[EC]
Host=localhost
Port=4712
Password=${AMULE_GUI_ENCODED_PWD}
[Webserver]
Port=4711
UPnPWebServerEnabled=0
UPnPTCPPort=50001
Template=AmuleWebUI-Reloaded
UseGzip=1
AllowGuest=0
AdminPassword=${AMULE_WEBUI_ENCODED_PWD}
GuestPassword=
EOM
    printf "%s successfullly generated.\n" "${REMOTE_CONF}"
else
    printf "%s file found. Using existing configuration.\n" "${REMOTE_CONF}"
fi

# Replace passwords
if [ -n "${GUI_PWD}" ]; then
    sed -i "s/^ECPassword=.*/ECPassword=${AMULE_GUI_ENCODED_PWD}/" "${AMULE_CONF}"
    sed -i "s/^Password=.*/Password=${AMULE_GUI_ENCODED_PWD}/" "${REMOTE_CONF}"
fi
if [ -n "${WEBUI_PWD}" ]; then
    sed -i "s/^Password=.*/Password=${AMULE_WEBUI_ENCODED_PWD}/" "${AMULE_CONF}"
    sed -i "s/^AdminPassword=.*/AdminPassword=${AMULE_WEBUI_ENCODED_PWD}/" "${REMOTE_CONF}"
fi

# Set permissions
chown -R "${AMULE_UID}:${AMULE_GID}" ${AMULE_INCOMING}
chown -R "${AMULE_UID}:${AMULE_GID}" ${AMULE_TEMP}
chown -R "${AMULE_UID}:${AMULE_GID}" ${AMULE_HOME}

# Modifications / Fixes
mod_auto_restart
mod_fix_kad_graph
mod_fix_kad_bootstrap

# Start aMule
while true; do
    mod_auto_share
    su "${AMULE_USER}" -s "/bin/sh" -c "amuled -c ${AMULE_HOME} -o"
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        printf "[MOD_AUTO_RESTART] Restarting aMule...\n"
    else
        printf "aMule exited with exit code: %d\n" "$EXIT_CODE"
        break
    fi
done
exit $EXIT_CODE
