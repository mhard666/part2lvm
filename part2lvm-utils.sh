#!/bin/bash

# part2lvm-utils.sh
#
# Funktionen für die gemeinsame Nutzung in allen part2lvm-Scripten
#
# v. 0.0.1  - 20210124  - mh    - initiale Version
#
# Author: Mirko Härtwig

# =================================================================================================
# Konstanten (0..255)
# =================================================================================================
# rWARNING_xxx : return Codes WARNING ab 1000
rWARNING_PathNotEmpty=109

# rERROR_xxx : return Codes ERROR ab 2000
rERROR_RunNotAsRoot=200
rERROR_WrongParameters=201
rERROR_FileNotFound=202

rERROR_FilesystemNotSupported=208
rERROR_PathNotEmpty=209
rERROR_PathNotExist=210
rERROR_IncludingFail=211
rERROR_NoRootEntryFstab=212
rERROR_MountUnsuccessful=213
rERROR_MountFailed=214

rERROR_UndefinedFailure=255


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
        echo ""
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
        echo ""
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


# =========================================================
# Funktion:     getFstab()
# Aufgabe:      holt /etc/fstab von der root-Partition
#               und legt sie im Live-System ab. Dazu wird
#               die root-Partition gemounted, die Datei
#               kopiert, anschließend die root-Partition
#.              wieder dismounted
# Parameter:    $1 root-Partition
#               $2 Mountpoint
#               $3 Zielverzeichnis (optional)
# Return:       0:    Ok
#               2001: Wenn Fehler in Parameterübergabe
# Echo:         String
# =========================================================
function getFstab {
    # Parameter prüfen
    if [ $# -lt 2 ]
    then
        echo "usage: $0 ROOTDEVICE MOUNTPOINT [DESTINATION]"
        log "regular" "ERROR" "getFstab(): ........................... Fehler bei Parameterübergabe"
        return $rERROR_WrongParameters
    fi

    # Übergabeparameter abholen
    gF_root=$1
    gF_mountpoint=$2
    gF_destination=$3

    # Prüfen, ob Zielverzeichnis leer ist
    if [ "$gF_destination" == "" ]; then

        # Zielverzeichnis ist leer -> Zielverzeichnis = pwd
        gF_destination=$(pwd)
    fi

    # Prüfen, ob das Zielverzeichnis nicht existiert
    if [ ! -d $gF_destination ]; then

        # Zielverzeichnis existiert nicht -> Abbruch
        log "regular" "ERROR" "getFstab(): ........................... Fehler $rERROR_PathNotExist Abbruch, Zielverzeichnis existiert nicht."
        return $rERROR_PathNotExist
    fi

    # Prüfen, ob Mountpoint existiert
    if [ -d $gF_mountpoint ]; then

        # Verzeichnis für Mountpoint existiert -> root mounten
        mount $gF_root $gF_mountpoint
        result=$?
        if [ $result -ne 0 ]; then

            # mount mit Fehler beendet -> Abbruch
            log "regular" "ERROR" "getFstab(): ........................... Fehler $result (root Partition konnte nicht temporär gemountet werden)"
            return $result
        fi

        # Mount-Eintrag ermitteln
        # $gF_root:          /dev/sda2
        # $gF_mountpoint:    /mnt/root
        found=$(mount | grep "$gF_mountpoint " | grep "$gR_root ")

        # Prüfen, ob Mounteintrag gefunden wurde
        if [ "$found" == "" ]; then

            # Mounteintrag nicht gefunden -> Abbruch
            log "regular" "ERROR" "getFstab(): ........................... Fehler $rERROR_MountUnsuccessful (kein Mount-Eintrag gefunden)"
            return $rERROR_MountUnsuccessful
        else

            # Mounteintrag gefunden
            echo "$gF_root wurde unter $gF_mountpoint gemounted..."

            # fstab ins scriptverzeichnis als fstab.tmp kopieren
            cp "$gF_mountpoint/etc/fstab" "$gF_destination/fstab.tmp"
            result=$?
            if [ $result -ne 0 ]; then

                # Fehler beim Kopieren -> Abbruch
                log "regular" "ERROR" "getFstab(): ........................... Fehler $rERROR_UndefinedFailure (Fehler beim Kopieren der fstab)"
                return $rERROR_UndefinedFailure
            else

                # kein Fehler beim kopieren -> Prüfen, ob Datei im Ziel erstellt wurde
                if [ ! -f "$gF_destination/fstab.tmp" ]; then

                    # nicht vorhanden
                    log "regular" "ERROR" "getFstab(): ........................... Fehler $rERROR_UndefinedFailure (fstab.tmp nicht vorhanden)"
                    return $rERROR_UndefinedFailure
                fi
            fi

            # root dismounten
            umount "$devSourcePartition"
            result=$?
            if [ $result -ne 0 ]; then

                # Dismount fehlgeschlagen
                log "regular" "ERROR" "getFstab(): ........................... Fehler $rERROR_UndefinedFailure (Dismount der temporär gemounteten root Partition fehlgeschlagen)"
                return $rERROR_UndefinedFailure
            fi
        fi
    else

        # Mountpoint nicht vorhanden
        log "regular" "ERROR" "getFstab(): ........................... Fehler $rERROR_UndefinedFailure (Mountpoint nicht vorhanden)"
        return $rERROR_PathNotExist
    fi

    # Erfolgreich durchgelaufen -> Rückgabewert 0
    return 0
}


# =========================================================
# Funktion:  getRootFromFstab()
# Aufgabe:   liefert den root-Eintrag aus einer fstab
#            Die fstab kann in einer Partition liegen,
#            welche vorher gemounted werden muss, oder an 
#            einer zu benennenden Stelle im Dateisystem.
# Parameter: $1 Path
# Return:    0: Wenn ok und root ein Device-String
#            1: Wenn ok und root ein UUID
#            $rERROR_xxxxxx: Bei Fehler.
# =========================================================
function getRootFromFstab() {
    # Parameter prüfen
    if [ $# -lt 1 ]
    then
        echo "usage: $0 PATH"
        return $rERROR_WrongParameters
    fi

    # Übergabeparameter abholen
    gRFF_Path=$1

    # Prüfen, ob gRFF_Path als Datei existiert
    if [ -f $gRFF_Path ]; then 

        # Datei existiert -> Zeile mit root-Eintrag ermitteln.
        row=$(grep -E '^[^#].+\s\/\s{2,}(ext[2-4]|xfs|btrfs)' $gRFF_Path)

        # Prüfen, ob $row != "" (Wenn $row != "" ist eine root-Partition vorhanden...)
        if [ "$row" != "" ]; then

            # $row ist nicht leer -> es wurde ein Eintrag für eine root-Partition geliefert
            # Ergebnis in $row zerlegen und den ersten Block zurückgeben (das root-Filesystem, entweder als UUID oder Device)
            # UUID:   UUID=xxxxx-xxxxxx-xxxxxx-xxxxxx
            # Device: /dev/sda3
            rootEntry=$(echo "$row" | awk '{print $1}')

            # $rootEntry zerlegen
            rootUuid=$(echo "$rootEntry" | grep "UUID")
            if [ "$rootUuid" != "" ]; then

                # rootEntry mit UUID gefunden -> ausgeben
                echo $(echo "$rootUuid" | awk -F'=' '{print $2}')
                return 1
            else

                # rootEntry mit Device -> ausgeben
                echo $rootEntry
            fi

            # Rückgabewert 0 - alles ok.
            return 0
        else

            # Es wurde keine root-Partition geliefert -> Fehler und Abbruch
            log "regular" "ERROR" "getRootFromFstab: ..................... Fehler $rERROR_NoRootEntryFstab (kein root-Eintrag in fstab)"
            return $rERROR_NoRootEntryFstab
        fi
    else

        # Datei existiert nicht oder Pfad ist keine Datei
        log "regular" "ERROR" "getRootFromFstab: ..................... Fehler $rERROR_FileNotFound (fstab nicht gefunden oder Pfad ist keine Datei)"
        return $rERROR_FileNotFound
    fi
}
