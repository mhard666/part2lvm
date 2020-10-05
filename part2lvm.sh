#!/bin/bash

# part2lvm.sh
# v. 0.0.2  - 20200811  - mh    - LVM einrichtung vollständig, ungetestet
# v. 0.0.1  - 20200811  - mh    - initiale Version
#
# Author: Mirko Härtwig

# Konstanten
# rWARNING_xxx : return Codes WARNING ab 1000
rWARNING_PathNotEmpty=1000

# rERROR_xxx : return Codes ERROR ab 2000
rERROR_RunNotAsRoot=2000
rERROR_WrongParameters=2001
rERROR_FileNotFound=2002
rERROR_PathNotExist=2010
rERROR_IncludingFail=2011
rERROR_NoRootEntryFstab=2012


# Logging einbinden...
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
# Funktion:     fillEmptyVars()
# Aufgabe:      füllt eine Variable mit einem vorgegebenen
#               String, wenn diese leer ist
# Parameter:    $1 zu prüfender String
#               $2 Füllstring
# Return:       0: Ok
#               2: Wenn Fehler in Parameterübergabe
# Echo:         String
# =========================================================
function fillEmptyVars {
    # Parameter prüfen
    if [ $# -lt 2 ]
    then
        log "regular" "ERROR" "FUNC: fillEmptyVars(): Fehler bei Parameterübergabe"
        return $rERROR_WrongParameters
    fi

    # Übergabeparameter abholen
    fEVInString=$1
    fEVFiller=$2

    # echo $1
    if [ "$fEVInString" == "" ]; then
        log "regular" "INFO" "FUNC: fillEmptyVars(): InString is empty"
        # Input-String ist leer - mit Füllstring füllen
        echo $fEVFiller
        return 0
    else
        log "regular" "INFO" "FUNC: fillEmptyVars(): InString not empty"
        # Input-String ist nicht leer - Input string zurückgeben
        echo $fEVInString
        return 0
    fi
}

# =========================================================
# Funktion:     stripEmptyVars()
# Aufgabe:      entfernt in einer Variable mit einem 
#               vorgegebenen String und gibt einen leeren
#               String zurück
# Parameter:    $1 zu prüfender String
#               $2 Füllstring
# Return:       0: Ok
#               2: Wenn Fehler in Parameterübergabe
# Echo:         String
# =========================================================
function stripEmptyVars {
    # Parameter prüfen
    if [ $# -lt 2 ]
    then
        log "regular" "ERROR" "FUNC: stripEmptyVars(): Fehler bei Parameterübergabe"
        return $rERROR_WrongParameters
    fi

    # Übergabeparameter abholen
    sEVInString=$1
    sEVFiller=$2

    # echo $1
    if [ "$sEVInString" == "$sEVFiller" ]; then
        log "regular" "INFO" "FUNC: stripEmptyVars(): InString == Filler"
        # Input-String ist gleich Füllstring - leeren String setzen
        echo ""
        return 0
    else
        log "regular" "INFO" "FUNC: stripEmptyVars(): InString != Filler"
        # Input-String ungleich Füllstring - Input string zurückgeben
        echo $sEVInString
        return 0
    fi
}

log "begin" "INFO" "Script $0 gestartet."

# Check if script is running as root...
SYSTEM_USER_NAME=$(id -un)
if [[ "${SYSTEM_USER_NAME}" != 'root'  ]]
then
    log "regular" "ERROR" "Script nicht mit root-Privilegien gestartet - Abbruch"
    echo 'You are running the script not as root'
    exit $rERROR_RunNotAsRoot
fi


# Variablen...
fsSourceRootDrive="/dev/sda"
fsSourceBootDrive="/dev/sda"
fsSourceRootPartition="/dev/sda2"
fsSourceBootPartition="/dev/sda1"

mntSrc="/mnt/src"               # Mountpoint Quelle
mntDst="/mnt/dst"               # Mountpoint Ziel

filler="none"                   # Füllwert, mit dem leere Variablen befüllt werden

# STEP 1: LVM AUF DER NEUEN PARTITION EINRICHTEN
# ==============================================

# Physical Volume auf der neuen Partition (sda3) anlegen
lvmPvDevice="/dev/sda3"
log "regular" "DEBUG" "pvcreate $lvmPvDevice"
pvcreate $lvmPvDevice

# Volume Group im Physical Volume anlegen
lvmVgName="vg_debian"
log "regular" "DEBUG" "vgcreate $lvmVgName $lvmPvDevice"
vgcreate $lvmVgName $lvmPvDevice

# Logical Volumes anlegen
# lvmLvName lvmLvSize fsType fsMountPoint fsTempMountPoint
### ToDo: fsTempMountPoint rausnehmen
lvmLogicalVolumeData='lv_root 10G ext4 / /mnt/dst
lv_swap 16G swap
lv_home 20G ext4 /home /mnt/dst/home
lv_opt 2G ext4 /opt /mnt/dst/opt
lv_var 5G ext4 /var /mnt/dst/var
lv_var_log 5G ext4 /var/log /mnt/dst/var/log
lv_var_tmp 5G ext4 /var/tmp /mnt/dst/var/tmp
lv_var_lib_postgresql 40G ext4 /var/lib/postgresql /mnt/dst/var/lib/postgresql'

#zum testen...
lvmLogicalVolumeData='lv_root 3G ext4 / /mnt/dst
lv_swap 1G swap
lv_home 2G ext4 /home /mnt/dst/home
lv_opt 1G ext4 /opt /mnt/dst/opt
lv_var 2G ext4 /var /mnt/dst/var
lv_var_log 2G ext4 /var/log /mnt/dst/var/log
lv_var_tmp 2G ext4 /var/tmp /mnt/dst/var/tmp
lv_var_lib_postgresql 2G ext4 /var/lib/postgresql /mnt/dst/var/lib/postgresql'

# Variable zur Zeilenweisen Aufbereitung der Ergebnisse aus dem vorhergehenden Loop zur Weiterverarbeitung im nächsten Loop
nextLoop=""

log "regular" "INFO" "START Loop1 ====================================================================================="
while read -r line
do 
    log "regular" "DEBUG" "------------------------ loop:"
    lvmLvName=$(echo "$line" | awk '{print $1}')
    lvmLvSize=$(echo "$line" | awk '{print $2}')
    fsType=$(echo "$line" | awk '{print $3}')
    fsMountPoint=$(echo "$line" | awk '{print $4}')
    # fsTempMountPoint=$(echo "$line" | awk '{print $5}')
    fsTempMountPoint="$mntDst$fsMountPoint"

    log "regular" "DEBUG" "lvmLvName: ................... $lvmLvName"
    log "regular" "DEBUG" "lvmLvSize: ................... $lvmLvSize"
    log "regular" "DEBUG" "fsType: ...................... $fsType"
    log "regular" "DEBUG" "fsMountPoint: ................ $fsMountPoint"
    log "regular" "DEBUG" "fsTempMountPoint: ............ $fsTempMountPoint"

    # Erstellen des Logical Volumes...
    lvcreate -L $lvmLvSize -n $lvmLvName $lvmVgName

    # Dateisysteme anlegen...
    if [ "$fsType" == "ext4" ]; then
        log "regular" "INFO" "Filesystem ist ext4"
        # Dateisysteme auf den LVs anlegen
        mkfs.ext4 "/dev/$lvmVgName/$lvmLvName"
    elif [ "$fsType" == "swap" ]; then
        log "regular" "INFO" "Filesystem ist swap"
        # Swap Filesystem anlegen
        mkswap "/dev/$lvmVgName/$lvmLvName"
    else
        # nicht unterstützt - Fehler
        log "regular" "WARN" "Kein unterstütztes Filesystem - übersprungen"
        echo "Kein unterstütztes Dateisystem - übersprungen."
    fi

    # Dateisysteme ausgeben, UUID ermitteln
    fsUUID=$(blkid | grep -i "\-$lvmLvName:" | grep -o -E '\"[0-9a-z]{8}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{12}\"')
    log "regular" "DEBUG" "fsUUID: ........................ $fsUUID"
    # Dateisysteme ausgeben, Mapper ermitteln
    fsMapper=$(blkid | grep -i "\-$lvmLvName:" | grep -o -E '\/dev\/mapper\/[0-9a-zA-Z\_\-]*')
    log "regular" "DEBUG" "fsMapper: .................... $fsMapper"

    
    # ERGEBISSE FÜR NÄCHSTE SCHLEIFE AUFARBEITEN

    # leere Variablen mit Dummy-Wert füllen
    lvmLvName=$(fillEmptyVars "$lvmLvName" "$filler")
    lvmLvSize=$(fillEmptyVars "$lvmLvSize" "$filler")
    fsType=$(fillEmptyVars "$fsType" "$filler")
    fsMountPoint=$(fillEmptyVars "$fsMountPoint" "$filler")
    fsTempMountPoint=$(fillEmptyVars "$fsTempMountPoint" "$filler")
    fsUUID=$(fillEmptyVars "$fsUUID" "$filler")
    fsMapper=$(fillEmptyVars "$fsMapper" "$filler")

    # Wenn nextLoop nicht leer ist erstmal einen Zeilenumbruch dranhängen...
    if [ "$nextLoop" != "" ] 
    then
        nextLoop+="\n"
    fi

    # Hier die aufbereiteten Zeilen hin, Spalten jeweils Leerzeichen-separiert
    ### ToDo: fsTempMountPoint rausnehmen
    nextLoop+="$lvmLvName $lvmLvSize $fsType $fsMountPoint $fsTempMountPoint $fsUUID $fsMapper"

done <<<"$lvmLogicalVolumeData"
log "regular" "INFO" "ENDE Loop1 ======================================================================================"


# NÄCHSTER LOOP: Neues Filesystem mounten und altes dahin syncen
# ==============================================================

# Prüfen ob Mountpoint vorhanden, wenn nicht Verzeichnis anlegen, wenn ja, 
pathExistsOrCreate $mntSrc
result=$?
if [ $result -eq 0 ]; then
    # Rückgabewert 0 - Verzeichnis existiert
    echo "0 - OK"
else
    # Rückgabewert 1 oder höher - Abbruch
    echo "$result - Abbruch"
    exit $result
fi

# prüfen ob Verzeichnis leer, wenn nicht, leeren...
pathEmptyOrDelContent $mntSrc
result=$?
if [ $result -eq 0 ]; then
    # Rückgabewert 0 - Verzeichnis ist leer
    echo "0"
elif [ $result -eq $rWARNING_PathNotEmpty ]; then
    # Rückgabewert 1 - Verzeichnis ist nicht leer - Warnung mit Option zum Abbruch
    echo "$result - Path not empty"
    ### ToDo: Abfrage Abbruch/Weiter?
else
    # Rückgabewert 2 und höher - Fehler bei Parameterübergabe - Abbruch
    echo "$result - Abbruch"
    exit $result
fi

# Souce mounten
log "regular" "DEBUG" "mount $fsSourceRootPartition $mntSrc"
mount "$fsSourceRootPartition" "$mntSrc"
### ToDo: Loggen der Mount-Ausgabe | grep $mntSrc
log "regular" "DEBUG" "$(mount | grep $mntSrc)"

# Jeden einzelnen Mountpoint im LVM mounten, Dateien syncen
x=$(echo -e "$nextLoop")

log "regular" "INFO" "START Loop2 ====================================================================================="
while read -r line 
do
    log "regular" "DEBUG" "-------------------------- loop:"

    lvmLvName=$(echo "$line" | awk '{print $1}')
    lvmLvSize=$(echo "$line" | awk '{print $2}')
    fsType=$(echo "$line" | awk '{print $3}')
    fsMountPoint=$(echo "$line" | awk '{print $4}')
    # fsTempMountPoint=$(echo "$line" | awk '{print $5}')
    fsTempMountPoint="$mntDst$fsMountPoint"
    fsUUID=$(echo "$line" | awk '{print $6}')
    fsMapper=$(echo "$line" | awk '{print $7}')

    # reconvert in leeren String wenn erforderlich
    lvmLvName=$(stripEmptyVars "$lvmLvName" "$filler")  
    lvmLvSize=$(stripEmptyVars "$lvmLvSize" "$filler")
    fsType=$(stripEmptyVars "$fsType" "$filler")
    fsMountPoint=$(stripEmptyVars "$fsMountPoint" "$filler")
    fsUUID=$(stripEmptyVars "$fsUUID" "$filler") 
    fsMapper=$(stripEmptyVars "$fsMapper" "$filler")

    log "regular" "DEBUG" "lvmLvName: ................... $lvmLvName"
    log "regular" "DEBUG" "lvmLvSize: ................... $lvmLvSize"
    log "regular" "DEBUG" "fsType: ...................... $fsType"
    log "regular" "DEBUG" "fsMountPoint: ................ $fsMountPoint"
    log "regular" "DEBUG" "fsTempMountPoint: ............ $fsTempMountPoint"
    log "regular" "DEBUG" "fsUUID: ...................... $fsUUID"
    log "regular" "DEBUG" "fsMapper: .................... $fsMapper"

    # Die weiteren Aktionen nur durchführen, wenn kein swap-FS geliefert wird...
    log "regular" "DEBUG" "if [ $fsType != swap ]"
    if [ "$fsType" != "swap" ]
    then
        log "regular" "INFO" "Filesystem ist kein swap-FS"
        
        # Prüfen ob Mountpoint vorhanden, wenn nicht Verzeichnis anlegen, wenn ja, 
        pathExistsOrCreate $fsTempMountPoint
        result=$?
        if [ $result -eq 0 ]; then
            # Rückgabewert 0 - Ok
            echo "true"
        else
            # Rückgabewert 1 und höher - Fehler
            echo "$result - Abbruch"
            exit $result
        fi

        # Prüfen ob der Mountpoint leer ist
        pathEmptyOrDelContent $fsTempMountPoint
        result=$?
        if [ $result -eq 0 ]; then
            # Rückgabewert 0 - Ok
            echo "0"
        elif [ $result -eq $rWARNING_PathNotEmpty ]; then
            # Rückgabewert 1 - Fehler, Verzeichnis nicht leer - Abfrage Abbruch/Weiter
            echo "$result - Path not empty"
            ### ToDo: Abfrage bei Fehler ob weiter oder Abbruch
        else
            # Rückgabewert 2 oder höher - Fehler bei Parameterübergabe - Abbruch
            echo "$result - Abbruch"
            exit $result
        fi

        # In Mountpoint mounten
        log "regular" "DEBUG" "mount /dev/$lvmVgName/$lvmLvName $fsTempMountPoint"
        mount "/dev/$lvmVgName/$lvmLvName" "$fsTempMountPoint"

        # prüfen, ob letztes Zeichen in $fsMountPoint ein / ist...
        if [ "${fsMountPoint:(-1)}" == "/" ]; then
            log "regular" "INFO" "Slash am Ende"
            echo Slash am Ende!
            fsTgt="$fsMountPoint"
            ### ToDo: Slash am Ende entfernen
        else
            log "regular" "INFO" "Kein Slash am Ende - / anhängen"
            echo kein slash am ende
            fsTgt="$fsMountPoint/" # Nur wenn letztes Zeichen nicht / ist
            ### ToDo: fsTgt ohne Slash am Ende
        fi
    
        log "regular" "DEBUG" "fsTgt: ........................ $fsTgt"

        # mal schauen, ob mount erfolgreich war
        mnt=$(mount | grep "$fsTempMountPoint")
        log "regular" "DEBUG" "mnt: .......................... $mnt"
        
        # Zielpfad im alten Mountpoint zusammensetzen...
        fsTgtPath="$mntSrc$fsTgt*"
        log "regular" "DEBUG" "fsTgtPath: .................... $fsTgtPath"
        log "regular" "DEBUG" "fsTgtPath: .................... ${fsTgtPath%/*}"

        if [ -d ${fsTgtPath%/*} ]; then
            # Dateien vom source ins neue Filesystem kopieren
            log "regular" "DEBUG" "rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* $fsTgtPath $fsTempMountPoint"
            # rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* "$fsOMP$fsTgt*" "$fsTempMountPoint"
            rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* $fsTgtPath $fsTempMountPoint
        fi
    fi

done <<<"$x"
log "regular" "INFO" "ENDE Loop2 ======================================================================================"

echo "Taste drücken..."
read $x


# FSTAB IM NEUEN ROOT ANPASSEN
# ============================

fstab="$mntDst/etc/fstab"
log "regular" "DEBUG" "fstab: ....................... $fstab"

# prüfen, ob fstab am angegebenen Ort existiert...
if [ -f "$fstab" ]; then
    # prüfen, ob ein /boot Eintrag existiert - wenn nicht, evtl. abbruch
    row=$(grep -E '^[^#].+\s\/boot\s{2,}ext[2-4]' $fstab)
    log "regular" "DEBUG" "row: ......................... $row"

    # prüfen ob row != "", sonst ist keine extra boot Partition vorhanden, was ggf die einrichtung des Bootloaders verkompliziert...
    if [ "$row" == "" ]
    then
        log "regular" "INFO" "row = leer - kein Eintrag für eine Bootpartition vorhanden"
        # Abfrage mit option zu beenden...
        log "regular" "WARN" "Keine boot Partiton gefunden"
        echo -n "WARNUNG: Es wurde kein /boot-Partition-Eintrag in der Datei /etc/fstab gefunden. Vermutlich befinden sich die Dateien unterhalb von /. Soll das Script trotzdem fortgesetzt werden [J/N]? "
        read $x
        ### ToDo: Abfrage...
    fi

    # $row zurücksetzen...
    row=""

    # alten root-Eintrag ermitteln.
    row=$(grep -n -E '^[^#].+\s\/\s{2,}(ext[2-4]|xfs|btrfs)' $fstab)
    log "regular" "DEBUG" "row: ......................... $row"

    # Prüfen ob $row != "" (Wenn $row != "" ist eine root-Partition vorhanden...)
    if [ "$row" != "" ]
    then
        log "regular" "INFO" "Es wurde ein Eintrag für eine root-Partition gefunden"
        # Ergebnis in $row zerlegen in den Zeilentext...
        oldRoot=$(echo $row | awk -F':' '{print $2}')
        # ...und die Zeilennummer
        oldRootLine=$(echo $row | awk -F':' '{print $1}')

        log "regular" "DEBUG" "oldRoot: .................................. $oldRoot"
        log "regular" "DEBUG" "oldRootLine: .............................. $oldRootLine"

        # ersetzen von Zeile $oldRootLine mit '# $oldRoot'
        # nur anzeigen!
        ## sed "$oldRootLine c \
        ## # $oldRoot" $fstab

        # pipen (funktioniert evtl nicht!)
        cat $fstab | sed "$oldRootLine c \
        # $oldRoot" > $fstab

        # in temporäre Datei schreiben und diese in die Originaldatei moven
        ## sed "$oldRootLine c \
        ## # $oldRoot" $fstab > tmp
        ## mv tmp $fstab


    else
        log "regular" "INFO" "Es wurde kein Eintrag für eine root-Partition gefunden"
        # wenn keine root-Partition vorhanden ist: Fehler und Abbruch.
        log "regular" "ERROR" "Kein Eintrag für root-Filesystem in $fstab gefunden. Script wird beendet."
        echo "FEHLER: Kein root-Filesystem-Eintrag in $fstab gefunden. Das Script wird abgebrochen."
        exit $rERROR_NoRootEntryFstab
    fi
else
    log "regular" "ERROR" "Datei $fstab nicht vorhanden, Abbruch."
    echo "FEHLER: Datei $fstab nicht vorhanden, Abbruch."
    exit $rERROR_FileNotFound
fi


# NÄCHSTER LOOP: Logical Volumes in /etc/fstab eintragen
# ======================================================

x=$(echo -e "$nextLoop")

log "regular" "DEBUG" "START Loop3 ===================================================================================="
while read -r line 
do
    log "regular" "DEBUG" "-------------------- loop:"
    echo " ---> $line"
    lvmLvName=$(echo "$line" | awk '{print $1}')
    lvmLvSize=$(echo "$line" | awk '{print $2}')
    fsType=$(echo "$line" | awk '{print $3}')
    fsMountPoint=$(echo "$line" | awk '{print $4}')
    # fsTempMountPoint=$(echo "$line" | awk '{print $5}')
    fsTempMountPoint="$mntDst$fsMountPoint"
    fsUUID=$(echo "$line" | awk '{print $6}')
    fsMapper=$(echo "$line" | awk '{print $7}')

    # reconvert in leeren String wenn erforderlich
    lvmLvName=$(stripEmptyVars "$lvmLvName" "$filler")  
    lvmLvSize=$(stripEmptyVars "$lvmLvSize" "$filler")
    fsType=$(stripEmptyVars "$fsType" "$filler")
    fsMountPoint=$(stripEmptyVars "$fsMountPoint" "$filler")
    fsUUID=$(stripEmptyVars "$fsUUID" "$filler") 
    fsMapper=$(stripEmptyVars "$fsMapper" "$filler")

    # kein Mountpoint, dann auf "none" setzen (swap)
    if [ "$fsMountPoint" == "" ]; then 
        log "regular" "INFO" "MountPoint ist leer, auf none setzen."
        $fsMountPoint="none" 
    fi

    fsOptions="defaults"
    fsDump="0"
    fsPass="2"
    isRoot="0"

    log "regular" "DEBUG" "fsOptions: .............................. $fsOptions"
    log "regular" "DEBUG" "fsDump: ................................. $fsDump"
    log "regular" "DEBUG" "fsPass: ................................. $fsPass"
    log "regular" "DEBUG" "isRoot: ................................. $isRoot"

    # bei swap-Filesystem Variablen $fsPass und $fsOptions abweichend vom Default-Wert belegen
    # bei root-Partition Variablen $fsPass und $fsOptions abweichend von Default-Wert belegen
    if [ "$fsType" == "swap" ] 
    then
        log "regular" "INFO" "fsType is SWAP..." 
        fsOptions="sw" 
        fsPass="0"
        
        log "regular" "DEBUG" "fsOptions: .............................. $fsOptions"
        log "regular" "DEBUG" "fsPass: ................................. $fsPass"
    elif [ "$fsMountPoint" == "/" ] 
    then
        log "regular" "INFO" "Mountpoint is /..."
        fsOptions="errors=remount-ro"
        fsPass="1"
        isRoot="1"
        
        log "regular" "DEBUG" "fsOptions: .............................. $fsOptions"
        log "regular" "DEBUG" "fsPass: ................................. $fsPass"
        log "regular" "DEBUG" "isRoot: ................................. $isRoot"
    fi

    # <file system>                  <mount point>   <type>  <options>          <dump>  <pass>
    # /dev/mapper/debian--vg-root    /               ext4    errors=remount-ro  0       1
    # /dev/mapper/debian--vg-home    /home           ext4    defaults           0       2
    # /dev/mapper/debian--vg-tmp     /tmp            ext4    defaults           0       2
    # /dev/mapper/debian--vg-var     /var            ext4    defaults           0       2
    # /dev/mapper/debian--vg-swap_1  none            swap    sw                 0       0

    # <file system> <mount point>   <type>  <options>       <dump>  <pass>
    #           1   1     2         3       3 4         5   5     6 6       7
    # 0....5....0...45....0....5....0....5..8.0....5....0...45....0.2..5....0
    # 13            15              7       15              7       6

    # Variablenlänge formatieren...
    fsMapper=$(printf "%-13s" $fsMapper)
    fsMountPoint=$(printf "%-15s" $fsMountPoint)
    fsType=$(printf "%-7s" $fsType)
    fsOptions=$(printf "%-15s" $fsOptions)
    fsDump=$(printf "%-7s" $fsDump)
    # fsPass=$(printf "%-16s" $fsPass)

    # fstab-Zeile bauen...
    fsTabLine="$fsMapper $fsMountPoint $fsType $fsOptions $fsDump $fsPass"

    log "regular" "DEBUG" "<file system> <mount point>   <type>  <options>       <dump>  <pass>"
    log "regular" "DEBUG" "$fsTabLine"

    # Prüfen ob root-Partition - dann unterhalb der auskommentierten Zeile einfügen    
    if [ "$isRoot" == "1" ]
    then
        log "regular" "INFO" "Mountpoint für Root Partition..."
        # neue UID unter der der auskommentierten, alten root partition anfügen
        sed "$oldRootLine a \
            $fsTabLine" $fstab
    # sonst ist es keine root-Partition - dann am Ende der Datei einfügen...
    else
        log "regular" "INFO" "keine Root Partition..."
        # Anzahl Zeilen ermitteln = letzte Zeile
        lastRowLine=$(cat $fstab | wc -l)
        # neue UID der xxx part anfügen
        sed "$lastRowLine a \
            $fsTabLine" $fstab
    fi
done <<<"$x"
log "regular" "DEBUG" "ENDE Loop3 ====================================================================================="


# GRUB AKTUALISIEREN
# ==================

# /boot mounten...
### ToDo: Verzeichnis erstellen prüfen etc.
dstBoot="/mnt/dst/boot"

# Prüfen ob Mountpoint vorhanden, wenn nicht Verzeichnis anlegen, wenn ja, 
pathExistsOrCreate $dstBoot
result=$?
if [ $result -eq 0 ]; then
    log "result" "INFO" "MountPoint $dstBoot ist vorhanden..."
    # Rückgabewert 0 - Ok
    echo "true"
else
    log "regular" "ERROR" "MountPoint $dstBoot ist nicht vorhanden und konnte auch nicht angelegt werden."
    # Rückgabewert 1 und höher - Fehler
    echo "$result - Abbruch"
    exit $result
fi

# Prüfen ob der Mountpoint leer ist
pathEmptyOrDelContent $dstBoot
result=$?
if [ $result -eq 0 ]; then
    log "regular" "INFO" "MountPoint $dstBoot enthält keine Dateien oder Verzeichnisse."
    # Rückgabewert 0 - Ok
    echo "0"
elif [ $result -eq $rWARNING_PathNotEmpty ]; then
    log "regular" "WARNING" "MountPoint $dstBoot enthält Daten und diese konnten auch nicht gelöscht werden."
    # Rückgabewert 1 - Fehler, Verzeichnis nicht leer - Abfrage Abbruch/Weiter
    echo "$result - Path not empty"
    ### ToDo: Abfrage bei Fehler ob weiter oder Abbruch
else
    # Rückgabewert 2 oder höher - Fehler bei Parameterübergabe - Abbruch
    log "regular" "ERROR" "Sonstiger Fehler - Abbruch."
    echo "$result - Abbruch"
    exit $result
fi

mount "$fsSourceBootPartition" "$dstBoot"
log "regular" "DEBUG" "$(mount | grep $dstBoot)"

# Mounten der kritischen virtuellen Dateisysteme
for i in /dev /dev/pts /proc /sys /run; do 
    mount -B $i /mnt/dst$i
    log "regular" "DEBUG" "$(mount | grep /mnt/dst$i)" 
done

# Chroot into your normal system device:
chroot /mnt/dst

# Reinstall GRUB 2 
grub-install "$fsSourceBootDrive"

# Recreate the GRUB 2 menu file (grub.cfg)
update-grub

# Exit chroot: CTRL-D on keyboard