#!/usr/bin/env sh

mod_auto_restart() {
    MOD_AUTO_RESTART_ENABLED=${MOD_AUTO_RESTART_ENABLED:-"false"}
    MOD_AUTO_RESTART_CRON=${MOD_AUTO_RESTART_CRON:-"0 6 * * *"} # every day at 6:00 h
    if [ "${MOD_AUTO_RESTART_ENABLED}" = "true" ]; then
        # Fix bugs https://github.com/ngosang/docker-amule/issues/7
        # Auto restart amuled process. The cron scheduler is configurable.
        printf "[MOD_AUTO_RESTART] aMule will be restarted automatically (cron %s)... You can disable this mod with MOD_AUTO_RESTART_ENABLED=false\n" "$MOD_AUTO_RESTART_CRON"
        # Avoid adding several times the same cron task when the container restarts
        if ! grep -q "MOD_AUTO_RESTART" "/etc/crontabs/root" ; then
            printf "%s /bin/sh -c 'echo \"[MOD_AUTO_RESTART] Restarting aMule...\" && s6-svc -t /etc/services.d/amuled'\n" "$MOD_AUTO_RESTART_CRON" >> /etc/crontabs/root
        fi
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
            chown "${AMULE_USER}:${AMULE_GROUP}" "${AMULE_HOME}/nodes.dat"
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
        SHAREDDIR_CONF="${AMULE_HOME}/shareddir.dat"
        SHAREDDIR_TMP="${SHAREDDIR_CONF}.tmp"
        printf "%s\n" "${AMULE_INCOMING}" > "$SHAREDDIR_TMP"
        IFS=';'
        # shellcheck disable=SC2086
        set -- $MOD_AUTO_SHARE_DIRECTORIES
        for raw_dir in "$@"; do
            dir=$(printf '%s' "$raw_dir" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            [ -z "$dir" ] && continue
            if [ -d "$dir" ]; then
                printf "[MOD_AUTO_SHARE] Sharing directory '%s' with sub-directories...\n" "$dir"
                find "$dir" -type d >> "$SHAREDDIR_TMP"
            else
                printf "[MOD_AUTO_SHARE] Skipping missing directory '%s'\n" "$dir"
            fi
        done
        sort -u "$SHAREDDIR_TMP" > "$SHAREDDIR_CONF"
        rm -f "$SHAREDDIR_TMP"
        chown "${AMULE_USER}:${AMULE_GROUP}" "$SHAREDDIR_CONF"
        # Read-only file because aMule rewrites it on the first run
        chmod 444 "$SHAREDDIR_CONF"
    fi
}
