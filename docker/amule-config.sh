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
AMULEAPI_CONF=${AMULE_HOME}/amuleapi.conf
AMULEAPI_PASSWORDS=${AMULE_HOME}/amuleapi-passwords

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
MaxConnectionsPerFiveSeconds=50
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
MinFreeDiskSpace=500
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
GeoIPEnabled=1
VideoPlayer=
StatGraphsInterval=3
statsInterval=30
DownloadCapacity=12500
UploadCapacity=2500
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
AuthFailureThreshold=10
AuthFailureWindowSeconds=60
AuthLockoutSeconds=300
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
[AmuleApi]
Enabled=0
BindAddress=127.0.0.1
HttpPort=4713
[MediaMetadata]
Enabled=1
FFProbePath=
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
    AMULE_CONF_CREATED=true
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

# Ensure WebServer and amuleapi are not started by amuled (they run as their own services)
sed -i '/^\[WebServer\]/,/^\[/{s/^Enabled=.*/Enabled=0/}' "${AMULE_CONF}"
sed -i '/^\[AmuleApi\]/,/^\[/{s/^Enabled=.*/Enabled=0/}' "${AMULE_CONF}"

# Enable IP2Country on configurations created before 3.1.0. amuled writes GeoIPSource when
# it saves the preferences, so this only runs once and a later opt-out is respected
if ! grep -q '^GeoIPSource=' "${AMULE_CONF}"; then
    sed -i 's/^GeoIPEnabled=.*/GeoIPEnabled=1/' "${AMULE_CONF}"
fi

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

# Set permissions. Every ownership change in the image goes through this function, so a
# failure never stops the container: on network mounts (NFS, CIFS/SMB) chown is usually
# rejected and the ownership comes from the export or from the mount options instead
fix_permissions() {
    chown -R "${AMULE_UID}:${AMULE_GID}" "$1" 2>/dev/null && return 0
    printf "[INIT] WARNING: could not change the ownership of %s. This is expected on NFS or CIFS/SMB mounts: set PUID/PGID to match the share, or set FIX_PERMISSIONS=false to skip this step for the download directories.\n" "$1"
}

# Configure amuleapi (new Web UI + REST API), unless the legacy amuleweb was requested
if [ "${LEGACY_AMULEWEB_ENABLED}" != "true" ]; then
    # amuleapi.conf holds the EC password in plaintext (amuleapi hashes it itself), so it
    # can only be written when GUI_PWD is set or the password was generated in this run
    if [ ! -f "${AMULEAPI_CONF}" ] && [ -z "${GUI_PWD}" ] && [ "${AMULE_CONF_CREATED}" != "true" ]; then
        printf "[INIT] ERROR: %s is missing and GUI_PWD is not set.\n" "${AMULEAPI_CONF}"
        printf "[INIT] amuleapi needs the plaintext Remote GUI (EC) password and it hashes it\n"
        printf "[INIT] itself, so the MD5 hash in amule.conf cannot be reused. Set GUI_PWD to a\n"
        printf "[INIT] password of your choice (amulegui/amulecmd clients must then use the new\n"
        printf "[INIT] one), or set LEGACY_AMULEWEB_ENABLED=true to keep the legacy Web UI.\n"
        exit 1
    fi

    if [ ! -f "${AMULEAPI_CONF}" ]; then
        printf "[INIT] File %s NOT found. Generating new default configuration ...\n" "${AMULEAPI_CONF}"
        cat > ${AMULEAPI_CONF} <<- EOM
[Server]
BindAddress=0.0.0.0
Port=4711
AllowCORS=0
StaticRoot=
[EC]
Host=127.0.0.1
Port=4712
Password=${AMULE_GUI_PWD}
Encryption=1
[Auth]
LoginFailureWindowSeconds=60
LoginFailureThreshold=5
LoginLockoutSeconds=300
[Streaming]
EventBusRingCapacity=16384
EOM
        printf "[INIT] File %s successfullly generated.\n" "${AMULEAPI_CONF}"
    else
        printf "[INIT] File %s found. Using existing configuration.\n" "${AMULEAPI_CONF}"
        # Keep the EC password in sync with amule.conf. Plaintext, so escape it for sed.
        if [ -n "${GUI_PWD}" ]; then
            ESCAPED_GUI_PWD=$(printf '%s' "${AMULE_GUI_PWD}" | sed -e 's/[\\&|]/\\&/g')
            sed -i "s|^Password=.*|Password=${ESCAPED_GUI_PWD}|" "${AMULEAPI_CONF}"
        fi
    fi

    # amuleapi refuses to start, and to run the --set-*-pass below, if any of its files
    # is readable by group or others. It creates them 600, so this is only for the ones
    # restored from a backup with looser permissions
    chmod 600 "${AMULEAPI_CONF}"
    chmod 600 "${AMULE_HOME}"/amuleapi-* 2>/dev/null || true

    # Web UI passwords. Stored salted and stretched, so they can only be replaced
    if [ -n "${WEBUI_PWD}" ] || [ ! -f "${AMULEAPI_PASSWORDS}" ]; then
        if [ -z "${WEBUI_PWD}" ] && [ "${AMULE_CONF_CREATED}" != "true" ]; then
            printf "[INIT] Web UI password: %s\n" "${AMULE_WEBUI_PWD}"
        fi
        amuleapi --config-dir="${AMULE_HOME}" --no-log-file --set-admin-pass="${AMULE_WEBUI_PWD}"
    fi
    # Defined but empty disables the read-only guest account, the amuleapi default
    if [ -n "${WEBUI_GUEST_PWD+x}" ]; then
        amuleapi --config-dir="${AMULE_HOME}" --no-log-file --set-guest-pass="${WEBUI_GUEST_PWD}"
    fi
fi

# The configuration directory is always chowned: amuled runs as PUID/PGID and cannot
# write there otherwise. FIX_PERMISSIONS only gates the download directories
fix_permissions "${AMULE_HOME}"
# Old image versions set shareddir-recursive.dat read-only (chmod 444) to work around an
# aMule 3.0.0 bug. aMule rewrites all three shareddir*.dat files on every share rescan, so
# a leftover read-only file fails with 'Permission denied'. The chown above doesn't fix modes
chmod u+rw "${AMULE_HOME}"/shareddir*.dat 2>/dev/null || true
if [ "${FIX_PERMISSIONS:-true}" = "true" ]; then
    fix_permissions "${AMULE_INCOMING}"
    fix_permissions "${AMULE_TEMP}"
fi
