#!/bin/sh

AMULE_HOME=/home/amule/.aMule
AMULE_CONF=${AMULE_HOME}/amule.conf

sleep 1
AMULED_PID=$(pidof amuled)
AMULE_WEB_PID=$(pidof amuleweb)
if [ -z ${AMULED_PID} ] ; then
    printf "[SVC-AMULEWEB] aMule is not running - Exit\n"
    exit 1
elif [ -z ${AMULE_WEB_PID} ] ; then
    printf "[SVC-AMULEWEB] aMuleWeb is not running - Starting it...\n"
    /usr/bin/amuleweb --amule-config-file=${AMULE_CONF}
    printf "[SVC-AMULEWEB] aMuleWeb process stopped\n"
else
    printf "[SVC-AMULEWEB] aMuleWeb is already running with PID ${AMULE_WEB_PID} - Attaching to it...\n"
    tail --pid=${AMULE_WEB_PID} -f /dev/null
    printf "[SVC-AMULEWEB] aMuleWeb process with PID ${AMULE_WEB_PID} stopped\n"
fi
