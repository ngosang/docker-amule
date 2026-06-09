#!/usr/bin/env sh

AMULE_UID=${PUID:-1000}
AMULE_GID=${PGID:-1000}

if [ -n "${INCOMING_DIR}" ]; then
    AMULE_INCOMING="${INCOMING_DIR}"
elif [ -d "/incoming" ]; then
    printf "[INIT] Legacy directory /incoming detected. Using it for backward compatibility.\n"
    AMULE_INCOMING="/incoming"
else
    AMULE_INCOMING="/downloads/incoming"
fi

if [ -n "${TEMP_DIR}" ]; then
    AMULE_TEMP="${TEMP_DIR}"
elif [ -d "/temp" ]; then
    printf "[INIT] Legacy directory /temp detected. Using it for backward compatibility.\n"
    AMULE_TEMP="/temp"
else
    AMULE_TEMP="/downloads/temp"
fi
AMULE_HOME=/home/amule/.aMule
AMULE_CONF=${AMULE_HOME}/amule.conf
REMOTE_CONF=${AMULE_HOME}/remote.conf

printf "[INIT] Starting aMule configuration ...\n"

# Create configuration files if don't exist
AMULE_GROUP="amule"
if grep -q ":${AMULE_GID}:" /etc/group; then
    printf "[INIT] Group %s already exists. Won't be created.\n" "${AMULE_GID}"
    AMULE_GROUP=$(getent group "${AMULE_GID}" | cut -d: -f1)
    printf "[INIT] Group %s with GID %s will be used as amule group.\n" "${AMULE_GROUP}" "${AMULE_GID}"
else
    printf "[INIT] Creating group %s with GID %s ...\n" "${AMULE_GROUP}" "${AMULE_GID}"
    groupadd -g "${AMULE_GID}" "${AMULE_GROUP}"
fi

AMULE_USER="amule"
if grep -q ":${AMULE_UID}:" /etc/passwd; then
    printf "[INIT] User %s already exists. Won't be added.\n" "${AMULE_UID}"
    AMULE_USER=$(getent passwd "${AMULE_UID}" | cut -d: -f1)
    printf "[INIT] User %s with UID %s will be used as amule user.\n" "${AMULE_USER}" "${AMULE_UID}"
else
    printf "[INIT] Creating user %s with UID %s ...\n" "${AMULE_USER}" "${AMULE_UID}"
    useradd -u "${AMULE_UID}" -g "${AMULE_GROUP}" -s "/usr/sbin/nologin" -d "/home/amule" -M -N -c "First Last,RoomNumber,WorkPhone,HomePhone" "${AMULE_USER}"
fi

if [ ! -d "${AMULE_INCOMING}" ]; then
    printf "[INIT] Directory %s does not exists. Creating ...\n" "${AMULE_INCOMING}"
    mkdir -p "${AMULE_INCOMING}"
fi

if [ ! -d "${AMULE_TEMP}" ]; then
    printf "[INIT] Directory %s does not exists. Creating ...\n" "${AMULE_TEMP}"
    mkdir -p "${AMULE_TEMP}"
fi

if [ ! -d ${AMULE_HOME} ]; then
    printf "[INIT] Directory %s NOT found. Creating directory ...\n" "${AMULE_HOME}"
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
    printf "[INIT] Remote GUI password: %s\n" "${AMULE_GUI_PWD}"
    printf "[INIT] Web UI password: %s\n" "${AMULE_WEBUI_PWD}"

    printf "[INIT] File %s NOT found. Generating new default configuration ...\n" "${AMULE_CONF}"
    cat > ${AMULE_CONF} <<- EOM
[eMule]
Nick=https://amule-org.github.io
QueueSizePref=50
MaxUpload=0
MaxDownload=0
SlotAllocation=20
Port=4662
UDPPort=4672
UDPEnable=1
Address=
Autoconnect=1
MaxSourcesPerFile=300
MaxConnections=500
MaxConnectionsPerFiveSeconds=20
RemoveDeadServer=1
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
FileBufferSizePref=1000
DAPPref=1
UAPPref=1
AllocateFullFile=0
OSDirectory=${AMULE_HOME}
OnlineSignature=0
OnlineSignatureUpdate=5
EnableTrayIcon=0
MinToTray=0
Notifications=0
ConfirmExit=1
StartupMinimized=0
3DDepth=10
ToolTipDelay=1
ShowOverhead=0
ShowInfoOnCatTabs=1
VerticalToolbar=0
GeoIPEnabled=0
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
IPFilterURL=https://upd.emule-security.org/ipfilter.zip
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
AutoRescanSharedDirs=1
FollowSymlinksInShares=1
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
KadNodesUrl=https://upd.emule-security.org/nodes.dat
Ed2kServersUrl=https://upd.emule-security.org/server.met
ShowRatesOnTitle=0
GeoLiteCountryUpdateUrl=
StatsServerName=Shorty's ED2K stats
StatsServerURL=https://ed2k.shortypower.org/?hash=
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
Enabled=0
Password=${AMULE_WEBUI_ENCODED_PWD}
PasswordLow=
Port=4711
WebUPnPTCPPort=50001
UPnPWebServerEnabled=0
UseGzip=1
UseLowRightsUser=0
PageRefreshTime=120
Template=
Path=amuleweb
[GUI]
HideOnClose=0
AppImageIntegrationDeclined=0
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
EOM
    printf "[INIT] File %s successfullly generated.\n" "${AMULE_CONF}"
else
    printf "[INIT] File %s found. Using existing configuration.\n" "${AMULE_CONF}"
fi

if [ ! -f ${REMOTE_CONF} ]; then
    printf "[INIT] Remote GUI password: %s\n" "${AMULE_GUI_PWD}"
    printf "[INIT] Web UI password: %s\n" "${AMULE_WEBUI_PWD}"

    printf "[INIT] File %s NOT found. Generating new default configuration ...\n" "${REMOTE_CONF}"
    cat > ${REMOTE_CONF} <<- EOM
Locale=
[EC]
Host=127.0.0.1
Port=4712
Password=${AMULE_GUI_ENCODED_PWD}
ZLIB=1
ForceZLIB=0
[WebServer]
Port=4711
UPnPWebServerEnabled=0
UPnPTCPPort=50001
Template=
UseGzip=1
AllowGuest=0
AdminPassword=${AMULE_WEBUI_ENCODED_PWD}
GuestPassword=
PageRefreshTime=120
EOM
    printf "[INIT] File %s successfullly generated.\n" "${REMOTE_CONF}"
else
    printf "[INIT] File %s found. Using existing configuration.\n" "${REMOTE_CONF}"
fi

# Ensure WebServer is not started by amuled
sed -i '/^\[WebServer\]/,/^\[/{s/^Enabled=.*/Enabled=0/}' "${AMULE_CONF}"

# Migrate configs from the removed AmuleWebUI-Reloaded theme to the default theme,
# unless the user mounted it (or any theme) as an external volume at that path.
if [ ! -d /usr/share/amule/webserver/AmuleWebUI-Reloaded ]; then
    sed -i 's/^Template=AmuleWebUI-Reloaded$/Template=/' "${AMULE_CONF}" "${REMOTE_CONF}"
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
chown -R "${AMULE_UID}:${AMULE_GID}" "${AMULE_HOME}"
if [ "${FIX_PERMISSIONS:-true}" = "true" ]; then
    chown -R "${AMULE_UID}:${AMULE_GID}" "${AMULE_INCOMING}"
    chown -R "${AMULE_UID}:${AMULE_GID}" "${AMULE_TEMP}"
fi
