#!/usr/bin/env sh

# Exit on error. For debug use set -x
set -e

# Configuration
. /home/amule/amule-config.sh

# Modifications / Fixes
printf "[INIT] Starting aMule mods ...\n"
. /home/amule/amule-mods.sh
mod_auto_restart
mod_fix_kad_graph
mod_fix_kad_bootstrap
mod_auto_share

# Hand off to S6 process supervisor
# Export dynamic variables so S6 services inherit them
export AMULE_USER AMULE_HOME AMULE_CONF
printf "[INIT] Starting supervisor ...\n"
exec /usr/bin/s6-svscan /etc/services.d
