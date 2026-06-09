#!/usr/bin/env sh

mod_auto_restart() {
    MOD_AUTO_RESTART_ENABLED=${MOD_AUTO_RESTART_ENABLED:-"false"}
    MOD_AUTO_RESTART_CRON=${MOD_AUTO_RESTART_CRON:-"0 6 * * *"} # every day at 6:00 h
    if [ "${MOD_AUTO_RESTART_ENABLED}" = "true" ]; then
        # Fix bugs https://github.com/ngosang/docker-amule/issues/7
        # Auto restart amuled process. The cron scheduler is configurable.
        printf "[MOD_AUTO_RESTART] aMule will be restarted automatically (cron %s)... You can disable this mod with MOD_AUTO_RESTART_ENABLED=false\n" "$MOD_AUTO_RESTART_CRON"
        # Avoid adding several times the same cron task when the container restarts
        CRON_FILE="/etc/cron.d/amule-auto-restart"
        if [ ! -f "$CRON_FILE" ]; then
            printf "%s root /bin/sh -c 'echo \"[MOD_AUTO_RESTART] Restarting aMule...\" && s6-svc -t /etc/services.d/amuled > /proc/1/fd/1 2>&1'\n" "$MOD_AUTO_RESTART_CRON" > "$CRON_FILE"
            chmod 0644 "$CRON_FILE"
        fi
    fi
}

mod_auto_share() {
    MOD_AUTO_SHARE_ENABLED=${MOD_AUTO_SHARE_ENABLED:-"false"}
    MOD_AUTO_SHARE_DIRECTORIES=${MOD_AUTO_SHARE_DIRECTORIES:-"${AMULE_INCOMING}"}
    if [ "${MOD_AUTO_SHARE_ENABLED}" = "true" ]; then
        # Share the user directories recursively, including sub-directories.
        # We write each directory as a recursive share root in shareddir-recursive.dat.
        # aMule 3.0.0+ then shares each root together with all its sub-directories and
        # auto-adds new ones at runtime (AutoRescanSharedDirs).
        printf "[MOD_AUTO_SHARE] Sharing the following directories recursively (incl. sub-directories): %s ... You can disable this mod with MOD_AUTO_SHARE_ENABLED=false\n" "$MOD_AUTO_SHARE_DIRECTORIES"
        SHAREDDIR_CONF="${AMULE_HOME}/shareddir-recursive.dat"
        SHAREDDIR_TMP="${SHAREDDIR_CONF}.tmp"
        : > "$SHAREDDIR_TMP"
        # Split MOD_AUTO_SHARE_DIRECTORIES on ';' into positional parameters
        IFS=';'
        # shellcheck disable=SC2086
        set -- $MOD_AUTO_SHARE_DIRECTORIES
        for raw_dir in "$@"; do
            # Trim leading/trailing whitespace and skip empty or missing directories
            dir=$(printf '%s' "$raw_dir" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            [ -z "$dir" ] && continue
            if [ -d "$dir" ]; then
                printf "%s\n" "$dir" >> "$SHAREDDIR_TMP"
            else
                printf "[MOD_AUTO_SHARE] Skipping missing directory '%s'\n" "$dir"
            fi
        done
        # Deduplicate the roots into the final file
        sort -u "$SHAREDDIR_TMP" > "$SHAREDDIR_CONF"
        rm -f "$SHAREDDIR_TMP"
        # Remove the legacy union file (older image versions enumerated sub-directories here)
        # so aMule regenerates it from the recursive roots.
        rm -f "${AMULE_HOME}/shareddir.dat"
        chown "${AMULE_USER}:${AMULE_GROUP}" "$SHAREDDIR_CONF"
        # Read-only: on the very first run aMule rewrites the shared-dir files (empty) while
        # persisting its initial preferences, before loading them. Keeping this file read-only
        # prevents that wipe, so aMule reads our recursive roots and regenerates shareddir.dat.
        chmod 444 "$SHAREDDIR_CONF"
    fi
}
