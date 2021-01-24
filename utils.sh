# Quelle: https://www.extrablog.info/index.php/2019/07/20/add-logging-functionality-to-bash-shell-scripts/

function log() {
##################################################
##
## printlog <Logtype> <Loglevel> <Logmessage>
## usage:
##        printlog <starttrans|stoptran|regular> <DEBUG|INFO|WARN|ERROR> <Message>
##        0 = DEBUG
##        1 = INFO
##        2 = WARN
##        3 = ERROR
#Loglevel nicht definiert Loggen auf Standard
if [ -z "${LOGLEVEL}" ]; then
    LOGLEVEL=1;
fi
#Logdir nicht definiert
if [ -z "${LOGDIR}" ]; then
    echo "WARN: LOGDIR nicht gesetzt! Ich nutze das Ausführungsverzeichnis $(pwd)/Log!"
    LOGDIR="$(pwd)/Log"
fi
# If now Logfile defined, it will automatically set.
if [ -z "${LOGFILE}" ]; then
    echo "WARN: LOGFILE nicht gesetzt! Ich nutze das Ausführungsverzeichnis $(pwd)/Log/run.txt!"
    LOGFILE="${LOGDIR}/logfile$(date +%Y-%m-%d ).log"
fi
#Loglevel nicht deifiniert Loggen auf Standard
if [ -z "${ENABLE_LOG}" ]; then
    echo "ERROR: ENABLE_LOG nicht gesetzt! Wird deaktiviert!"
    ENABLE_LOG=0;
fi
LOGTYPE=$1
LOGLEVELID=$2
LOGMSG=$3
CSVLOG="${LOGDIR}/run.csv"
if [ ! -d ${LOGDIR} ] ; then
    mkdir -p ${LOGDIR};
fi
## Map integer Loglevel to description
case "${LOGLEVELID}" in
    DEBUG) LOGLID=0;;
    INFO) LOGLID=1;;
    WARN) LOGLID=2;;
    ERROR) LOGLID=3;;
esac
if [ "${DEBUG}" -eq "1" ] ; then
    echodbg "DEBUG: $LOGMSG"
fi
## Prints only Messages based on LOGLEVEL and LOGTYPE
case "${LOGTYPE}" in
    begin)
    if [ ${LOGLID} -ge ${LOGLEVEL} ]; then
        # Logfile or STDOUT
        if [ ${ENABLE_LOG} -eq 1 ] ;then
            echo "================================================================================" >>${LOGFILE}
            echo "$(date +%Y_%m_%d-%H:%M:%S) ${LOGLEVELID}  ${LOGMSG}" >>${LOGFILE}
        else
            echo "$(date +%Y_%m_%d-%H:%M:%S) ${LOGLEVELID}  ${LOGMSG}";
        fi
    fi
    ;;
    end)
    if [ ${LOGLID} -ge ${LOGLEVEL} ]; then
        # Logfile or STDOUT
        if [ ${ENABLE_LOG} -eq 1 ] ;then
            echo "$(date +%Y_%m_%d-%H:%M:%S) ${LOGLEVELID}  ${LOGMSG}" >>${LOGFILE}
            echo "--------------------------------------------------------------------------------" >>${LOGFILE}
        else
            echo "$(date +%Y_%m_%d-%H:%M:%S) ${LOGLEVELID}  ${LOGMSG}";
        fi
    fi
    ;;
    regular)
    # Logs by LOGLEVEL
    if [ ${LOGLID} -ge ${LOGLEVEL} ]; then
        # Logfile or STDOUT
        if [ ${ENABLE_LOG} -eq 1 ] ;then
            echo "$(date +%Y_%m_%d-%H:%M:%S) ${LOGLEVELID}  ${LOGMSG}" >>${LOGFILE}
        else
            echo "$(date +%Y_%m_%d-%H:%M:%S) ${LOGLEVELID}  ${LOGMSG}";
        fi
    fi
    ;;
esac
}
