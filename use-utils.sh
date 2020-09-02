#!/bin/bash

LOGLEVEL="0"
ENABLE_LOG="1"
#Rund in Logging / Debug Mode only, means to print out log messages to STDOUT
DEBUG=0
LOGDIR="$(pwd)/log"
LOGFILE="$LOGDIR/$(date +%Y%m%d)_edf_globalextra.log"

#then source the utils.sh

if [ -f ./utils.sh ] ;then
. ./utils.sh
else
    echo "ERROR: ./utils.sh not available"
    exit 1;
fi

#For now it can be used like this:

#ENABLE_LOG="0"
log "begin" "INFO" "Script $0 starts now."
#ENABLE_LOG="1"
log "regular" "DEBUG" "Debug information maybe to verify some variables"
#ENABLE_LOG="0"
log "regular" "ERROR" "Something went wrong"

