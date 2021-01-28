#!/bin/bash

# part2lvm-utils.sh
#
# Funktionen für die gemeinsame Nutzung in allen part2lvm-Scripten
#
# v. 0.0.1  - 20210124  - mh    - initiale Version
#
# Author: Mirko Härtwig

# =================================================================================================
# Konstanten
# =================================================================================================
# rWARNING_xxx : return Codes WARNING ab 1000
rWARNING_PathNotEmpty=1009

# rERROR_xxx : return Codes ERROR ab 2000
rERROR_RunNotAsRoot=2000
rERROR_WrongParameters=2001
rERROR_FileNotFound=2002

rERROR_FilesystemNotSupported=2008
rERROR_PathNotEmpty=2009
rERROR_PathNotExist=2010
rERROR_IncludingFail=2011
rERROR_NoRootEntryFstab=2012
rERROR_MountUnsuccessful=2013
rERROR_MountFailed=2014

rERROR_UndefinedFailure=2499


# =================================================================================================
# Logging einbinden...
# =================================================================================================
LOGLEVEL="0"
ENABLE_LOG="1"
#Rund in Logging / Debug Mode only, means to print out log messages to STDOUT
DEBUG=0
LOGDIR="$(pwd)/log"
LOGFILE="$LOGDIR/$(date +%Y%m%d-%H%M%S)_part2lvm.log"

# Then source the utils.sh
if [ -f ./utils.sh ] ;then
    . ./utils.sh
else
    echo "ERROR: ./utils.sh not available"
    exit $rERROR_IncludingFail
fi


# =========================================================
# Funktion: checkRoot()
# Aufgabe:   Prüft, ob das Script mit root-Rechten
#            ausgeführt wird
# Parameter: -
# Return:    0: wenn mit root-Rechten gestartet
#            $rERROR_RunNotAsRoot: wenn nicht mit 
#               root-Rechten gestartet
# ToDo:      -
# =========================================================
function checkRoot() {
    # Check if script is running as root...
    SYSTEM_USER_NAME=$(id -un)
    if [[ "${SYSTEM_USER_NAME}" != 'root'  ]]
    then
        log "regular" "ERROR" "Script nicht mit root-Privilegien gestartet - Abbruch"
        echo 'You are running the script not as root'
        return $rERROR_RunNotAsRoot
    fi
}


# =========================================================
# Funktion:  pathExistsOrCreate()
# Aufgabe:   Prüft ob Verzeichnis existiert und legt es
#            ggf. neu an.
# Parameter: $1 zu prüfender Pfad
# Return:    0: wenn Verzeichnis existiert oder erfolg-
#               reich angelegt wurde
#            1: wenn Verzeichnis nicht existiert und 
#               nicht angelegt werden konnte
#            2: wenn kein Parameter angegeben wurde
# ToDo:      rekursiv ParentPath prüfen, anlegen
# =========================================================
function pathExistsOrCreate() {
    # Parameter prüfen
    if [ $# -lt 1 ]
    then
        echo "usage: $0 PATH"
        return $rERROR_WrongParameters
    fi

    # Übergabeparameter abholen
    pEOCPath=$1

    # Prüfen ob Verzeichnis existiert...
    if [ -d "$pEOCPath" ]
    then
        # Ja - alles ok.
        log "regular" "INFO" "FUNC: pathExistsOrCreate(): Verzeichnis $pEOCPath existiert."
        return 0    # Returncode 0 = Ok
    else
        # Nein - Verzeichnis anlegen...
        ### ToDo: prüfen ob ParentPath existiert, da 
        log "regular" "WARNING" "FUNC: pathExistsOrCreate(): Verzeichnis $pEOCPath existiert nicht - erstellen."
        log "regular" "DEBUG" "mkdir $pEOCPath"
        mkdir "$pEOCPath" -p
        # Nochmal prüfen ob Verzeichnis jetzt existiert...
        if [ -d "$pEOCPath" ]
        then
            # Ja - alles ok
            log "regular" "INFO" "FUNC: pathExistsOrCreate(): Verzeichnis $pEOCPath existiert."
            return 0    # Returncode 0 = Ok
        else
            # Nein - nicht gut - $false zurückgeben
            log "regular" "ERROR" "FUNC: pathExistsOrCreate(): Verzeichnis $pEOCPath konnte nicht erstellt werden"
            return $rERROR_PathNotExist
        fi 
    fi 
}


# =========================================================
# Funktion:  pathEmptyOrDelContent()
# Aufgabe:   Prüft ob Verzeichnis leer ist und löscht ggf.
#            den Inhalt, falls es nicht leer ist.
# Parameter: $1 zu prüfender Pfad
# Return:    0: wenn Verzeichnis leer ist oder erfolg-
#               reich geleert wurde
#            1: wenn Verzeichnis nicht vollständig 
#               geleert werden konnte
#            2: wenn kein Parameter übergeben wurde
# =========================================================
function pathEmptyOrDelContent() {
    # Parameter prüfen
    if [ $# -lt 1 ]
    then
        echo "usage: $0 PATH"
        return $rERROR_WrongParameters
    fi

    # Übergabeparameter abholen
    pEODCPath=$1

    #Prüfen, ob das Verzeichnis Dateien/Ordner enthält...
    if [ -n "$(ls -A $pEODCPath)" ]
    then
        # Ja - Verzeichnis ist nicht leer - Inhalte löschen...
        log "regular" "INFO" "FUNC: pathEmptyOrDelContent(): Verzeichnis $pEODCPath nicht leer - löschen"
        # Alles unterhalb des Mountpoint löschen
        find "$pEODCPath" -mindepth 1 -delete

        # Nochmal prüfen, ob das Verzeichnis jetzt immernoch Dateien/Ordner enthält...
        if [ -n "$(ls -A $pEODCPath)" ]
        then
            # Ja - Verzeichnis ist immernoch nicht leer - return $false
            log "regular" "WARNING" "FUNC: pathEmptyOrDelContent(): Verzeichnis $pEODCPath konnte nicht geleert werden."
            return $rWARNING_PathNotEmpty
        else
            # Nein - Verzeichnis ist leer.
            log "regular" "INFO" "FUNC: pathEmptyOrDelContent(): Inhalt von Verzeichnis $pEODCPath wurde erfolgreich gelöscht."
            return 0    # Returncode 0 = Ok
        fi
    else
        # Nein - Verzeichnis ist leer.
        log "regular" "INFO" "FUNC: pathEmptyOrDelContent(): Verzeichnis $pEODCPath ist leer."
        return 0    # Returncode 0 = Ok
    fi
}


# =========================================================
# Funktion:  prepareMountAndTest()
# Aufgabe:   bereitet Mountpoint vor, mountet das 
#            angegebene Gerät dorthin und prüft
#            abschließend, ob das Gerät erfolgreich
#            gemounted werden konnte
# Parameter: $1 Device
#            $2 Mountpoint
# Return:    0: wenn Gerät erfolgreich gemounted werden
#               konnte
# =========================================================
function prepareMountAndTest() {
    # Parameter prüfen
    if [ $# -lt 2 ]
    then
        echo "usage: $0 DEVICE MOUNTPOINT"
        return $rERROR_WrongParameters
    fi

    # Übergabeparameter abholen
    pMAT_Device=$1
    pMAT_Mountpoint=$2

    # Prüfen, ob der Mountpoint existiert, ggf. anlegen
    # pMAT_Mountpoint:      /mnt/src
    pathExistsOrCreate "$pMAT_Mountpoint"
    result=$?
    if [ $result -eq 0 ]; then

        # Rückgabewert 0 -> Verzeichnis existiert oder wurde angelegt
    else

        # Rückgabewert > 0 -> Fehler beim Anlegen des Verzeichnisses -> Abbruch
        return $rERROR_PathNotExist
    fi

    # Prüfen ob Mountpoint leer ist, ggf. löschen
    # pMAT_Mountpoint:      /mnt/src
    pathEmptyOrDelContent "$pMAT_Mountpoint"
    result=$?
    if [ $result -eq 0 ]; then

        # Rückgabewert 0 -> Verzeichnis existiert oder wurde angelegt
    elif [ $result -eq $rWARNING_PathNotEmpty ]; then

        # Rückgabewert = $rWARNING_PathNotEmpty -> Abfrage Abbruch/Weiter (wenn weiter, wird trotzdem 
        # in das Verzeichnis gemounted)
        return $rERROR_PathNotEmpty

        # ToDo: Abfrage Abbruch/Weiter
    else

        # Anderer Rückgabewert > 0 -> Fehler aufgetreten -> Abbruch
        return $rERROR_UndefinedFailure
    fi

    # Mounten
    # pMAI_Device:          /dev/sda2       Quell-Partition
    # pMAT_Mountpoint:      /mnt/src
    mount "$pMAT_Device" "$pMAT_Mountpoint"
    result=$?
    if [ $result -eq 0 ]; then

        # Rückgabewert 0 -> erfolgreich gemounted -> Gegenprüfung: mount -> Zeile mit MP und Device ermitteln
        # pMAT_Device:          /dev/sda2
        # pMAT_Mountpoint:      /mnt/src
        found=$(mount | grep "$pMAT_Mountpoint " | grep "$pMAT_Device ")

        # Prüfen ob Mounteintrag gefunden wurde
        if [ "$found" == "" ]; then

            # Mounteintrag nicht gefunden -> Abbruch
            return $rERROR_MountUnsuccessful
        else

            # Mounteintrag gefunden
            echo "$pMAT_Device wurde unter $pMAT_Mountpoint gemounted..."
        fi
    else

        # Rückgabewert > 0 -> Fehler beim Mounten der Source Partition -> Abbruch
        return $rERROR_MountFailed
    fi
    
    # Erfolgreich durchgelaufen
    return 0
}