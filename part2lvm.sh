#!/bin/bash

# part2lvm.sh
# v. 0.0.2  - 20200811  - mh    - LVM einrichtung vollständig, ungetestet
# v. 0.0.1  - 20200811  - mh    - initiale Version
#
# Author: Mirko Härtwig

# Check if script is running as root...
SYSTEM_USER_NAME=$(id -un)
if [[ "${SYSTEM_USER_NAME}" != 'root'  ]]
then
    echo 'You are running the script not as root'
    exit 1
fi

# Logging einbinden...
LOGLEVEL="0"
ENABLE_LOG="1"
#Rund in Logging / Debug Mode only, means to print out log messages to STDOUT
DEBUG=0
LOGDIR="$(pwd)/log"
LOGFILE="$LOGDIR/$(date +%Y%m%d)_part2lvm.log"

# Then source the utils.sh
if [ -f ./utils.sh ] ;then
    . ./utils.sh
else
    echo "ERROR: ./utils.sh not available"
    exit 1;
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
# =========================================================
function pathExistsOrCreate() {
    # Parameter prüfen
    if [ $# -lt 1 ]
    then
        echo "usage: $0 PATH"
        return 2    # Returncode 2 = Fehler, Übergabeparameter
    fi

    # Übergabeparameter abholen
    pEOCPath=$1

    # Prüfen ob Verzeichnis existiert...
    log "regular" "DEBUG" "if [ ! -d $pEOCPath ]"
    if [ -d "$pEOCPath" ]
    then
        # Ja - alles ok.
        log "regular" "INFO" "Verzeichnis $pEOCPath existiert."
        return 0    # Returncode 0 = Ok
    else
        # Nein - Verzeichnis anlegen...
        log "regular" "INFO" "Verzeichnis $pEOCPath existiert nicht - erstellen."
        log "regular" "DEBUG" "mkdir $pEOCPath"
        mkdir "$pEOCPath"
        # Nochmal prüfen ob Verzeichnis jetzt existiert...
        if [ -d "$pEOCPath" ]
        then
            # Ja - alles ok
            log "regular" "INFO" "Verzeichnis $pEOCPath existiert."
            return 0    # Returncode 0 = Ok
        else
            # Nein - nicht gut - $false zurückgeben
            log "regular" "INFO" "Verzeichnis $pEOCPath konnte nicht erstellt werden"
            return 1    # Returncode 1 = Fehler, Verzeichnis nicht vorhanden
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
        return 2    # Returncode 2 = Fehler, Übergabeparameter
    fi

    # Übergabeparameter abholen
    pEODCPath=$1

    #Prüfen, ob das Verzeichnis Dateien/Ordner enthält...
    log "regular" "DEBUG" "if [ -n $(ls -A $pEODCPath) ]"
    if [ -n "$(ls -A $pEODCPath)" ]
    then
        # Ja - Verzeichnis ist nicht leer - Inhalte löschen...
        log "regular" "INFO" "Mountverzeichnis $pEODCPath ist nicht leer - löschen"
        # Alles unterhalb des Mountpoint löschen
        log "regular" "DEBUG" "find $pEODCPath -mindepth 1 -delete"
        find "$pEODCPath" -mindepth 1 -delete

        # Nochmal prüfen, ob das Verzeichnis jetzt immernoch Dateien/Ordner enthält...
        if [ -n "$(ls -A $pEODCPath)" ]
        then
            # Ja - Verzeichnis ist immernoch nicht leer - return $false
            log "regular" "INFO" "Verzeichnis $pEODCPath konnte nicht geleert werden."
            return 1    # Returncode 1 = Fehler, Pfad nicht leer
        else
            # Nein - Verzeichnis ist leer.
            log "regular" "INFO" "Inhalt von Verzeichnis $pEODCPath wurde erfolgreich gelöscht."
            return 0    # Returncode 0 = Ok
        fi
    else
        # Nein - Verzeichnis ist leer.
        log "regular" "INFO" "Verzeichnis $pEODCPath ist leer."
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
        log "regular" "WARNING" "function fillEmptyVars() - Fehler Parameterübergabe"
        # echo "usage: $0 INSTRING FILLER"
        return 2    # Returncode 2 = Fehler, Übergabeparameter
    fi

    # Übergabeparameter abholen
    fEVInString=$1
    fEVFiller=$2

    # echo $1
    if [ "$fEVInString" == "" ]; then
        # Input-String ist leer - mit Füllstring füllen
        echo $fEVFiller
        return 0
    else
        # Input-String ist nicht leer - Input string zurückgeben
        echo $fEVInString
        return 0
    fi
}

log "regular" "INFO" "Script $0 gestartet."

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

log "regular" "INFO" "### Start Loop1..."
while read -r line
do 
    log "regular" "DEBUG" "read -r $line"
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
    log "regular" "DEBUG" "lvcreate -L $lvmLvSize -n $lvmLvName $lvmVgName"
    lvcreate -L $lvmLvSize -n $lvmLvName $lvmVgName

    # Dateisysteme anlegen...
    log "regular" "DEBUG" "if [ $fsType == ext4 ]"
    if [ "$fsType" == "ext4" ]; then
        log "regular" "INFO" "Filesystem ist ext4"
        # Dateisysteme auf den LVs anlegen
        log "regular" "DEBUG" "mkfs.ext4 /dev/$lvmVgName/$lvmLvName"
        mkfs.ext4 "/dev/$lvmVgName/$lvmLvName"
    elif [ "$fsType" == "swap" ]; then
        log "regular" "INFO" "Filesystem ist swap"
        # Swap Filesystem anlegen
        log "regular" "DEBUG" "mkswap /dev/$lvmVgName/$lvmLvName"
        mkswap "/dev/$lvmVgName/$lvmLvName"
    else
        # nicht unterstützt - Fehler
        log "regular" "INFO" "Kein unterstütztes Filesystem - übersprungen"
        echo "Kein unterstütztes Dateisystem - übersprungen."
    fi

    # Dateisysteme ausgeben, UUID ermitteln
    log "regular" "INFO" "fsUUID=\$(blkid | grep -i \-$lvmLvName: | grep -o -E \"[0-9a-z]{8}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{12}\")"
    dummy=$(blkid)
    log "regular" "DEBUG" "dummy: ....................... $dummy"
    dummy=$(blkid | grep -i "\-$lvmLvName:")
    log "regular" "DEBUG" "dummy: ....................... $dummy"
    fsUUID=$(blkid | grep -i "\-$lvmLvName:" | grep -o -E '\"[0-9a-z]{8}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{12}\"')
    log "regular" "DEBUG" "fsUUID: ...................... $fsUUID"
    # Dateisysteme ausgeben, Mapper ermitteln
    log "regular" "DEBUG" "fsMapper=\$(blkid | grep -i \-$lvmLvName: | grep -o -E \/dev\/mapper\/[0-9a-zA-Z\_\-]*)"
    fsMapper=$(blkid | grep -i "\-$lvmLvName:" | grep -o -E '\/dev\/mapper\/[0-9a-zA-Z\_\-]*')
    log "regular" "DEBUG" "fsMapper: .................... $fsMapper"

    
    # ERGEBISSE FÜR NÄCHSTE SCHLEIFE AUFARBEITEN

    # leere Variablen mit Dummy-Wert füllen
    fillEmptyVars "$lvmLvName" "$filler"
    fillEmptyVars "$lvmLvSize" "$filler"
    fillEmptyVars "$fsType" "$filler"
    fillEmptyVars "$fsMountPoint" "$filler"
    fillEmptyVars "$fsTempMountPoint" "$filler"
    fillEmptyVars "$fsUUID" "$filler"
    fillEmptyVars "$fsMapper" "$filler"

    # Wenn nextLoop nicht leer ist erstmal einen Zeilenumbruch dranhängen...
    if [ "$nextLoop" != "" ] 
    then
        nextLoop+="\n"
    fi

    # Hier die aufbereiteten Zeilen hin, Spalten jeweils Leerzeichen-separiert
    ### ToDo: Leere Variablen mit Dummy-Werten füllen, sonst gibt es probleme bei der Auswertung der Parameter im nächsten Loop!!!
    ### ToDo: fsTempMountPoint rausnehmen
    nextLoop+="$lvmLvName $lvmLvSize $fsType $fsMountPoint $fsTempMountPoint $fsUUID $fsMapper"


done <<<"$lvmLogicalVolumeData"
log "regular" "INFO" "### End Loop1..."


# NÄCHSTER LOOP: Neues Filesystem mounten und altes dahin syncen
# ==============================================================

### ToDo: fsOMP ersetzen durch mntSrc
# MountPoint für QuellFileSystem
fsOMP="$mntSrc"

# Prüfen ob Mountpoint vorhanden, wenn nicht Verzeichnis anlegen, wenn ja, 
# prüfen ob Verzeichnis leer, wenn nicht, leeren...
log "regular" "DEBUG" "if [ ! -d $fsOMP ]"
##if [ ! -d "$fsOMP" ]
##then
##    log "regular" "INFO" "Mountverzeichnis $fsOMP existiert nicht"
##    log "regular" "DEBUG" "mkdir $fsOMP"
##    mkdir "$fsOMP"
##    ### ToDo: ggf. Berechtigungen setzen, ggf. Abbruch bei Fehler
##    # chmod -R u=rwx,g+rw-x,o+rwx $mountpfad
##    # Script-Abbruch bei Fehler...
##else
##    log "regular" "INFO" "Verzeichnis $fsOMP existiert."
##fi 

pathExistsOrCreate $fsOMP
result=$?
if [ $result -eq 0 ]; then
    # Rückgabewert 0 - Verzeichnis existiert
    echo "0 - OK"
elif [ $result -eq 1 ]; then
    # Rückgabewert 1 - Verzeichnis existiert nicht - Abbruch
    echo "1 - Fehler"
    exit
else
    # Rückgabewert 2 oder höher - Fehler bei Parameterübergabe
    echo "2+ - Abbruch"
    exit 
fi

# Prüfen ob der Mountpoint leer ist
### ToDo: in Funktion auslagern
log "regular" "DEBUG" "if [ -n $(ls -A $fsOMP) ]"
##if [ -n "$(ls -A $fsOMP)" ]
##then
##    log "regular" "INFO" "Mountverzeichnis $fsOMP ist nicht leer - löschen"
##    # Alles unterhalb des Mountpoint löschen
##    log "regular" "DEBUG" "find $fsOMP -mindepth 1 -delete"
##    find "$fsOMP" -mindepth 1 -delete
##    ### ToDo: ggf. Warnung bei Fehler
##    # Warnung bei Fehler... (kann notfalls im Nachgang händisch entfernt werden)
##else
##    log "regular" "INFO" "Verzeichnis $fsOMP ist leer."
##fi

pathEmptyOrDelContent $fsOMP
result=$?
if [ $result -eq 0 ]; then
    # Rückgabewert 0 - Verzeichnis ist leer
    echo "0"
elif [ $result -eq 1 ]; then
    # Rückgabewert 1 - Verzeichnis ist nicht leer - Warnung mit Option zum Abbruch
    echo "1"
    ### ToDo: Abfrage Abbruch/Weiter?
else
    # Rückgabewert 2 und höher - Fehler bei Parameterübergabe - Abbruch
    echo "2"
    exit
fi


# Souce mounten
log "regular" "DEBUG" "mount $fsSourceRootPartition $fsOMP"
mount "$fsSourceRootPartition" "$fsOMP"

# Jeden einzelnen Mountpoint im LVM mounten, Dateien syncen
x=$(echo -e "$nextLoop")

log "regular" "INFO" "### Start Loop2..."
while read -r line 
do
    log "regular" "DEBUG" "line: ........................ $line"

    lvmLvName=$(echo "$line" | awk '{print $1}')
    lvmLvSize=$(echo "$line" | awk '{print $2}')
    fsType=$(echo "$line" | awk '{print $3}')
    fsMountPoint=$(echo "$line" | awk '{print $4}')
    # fsTempMountPoint=$(echo "$line" | awk '{print $5}')
    fsTempMountPoint="$mntDst$fsMountPoint"
    fsUUID=$(echo "$line" | awk '{print $6}')
    fsMapper=$(echo "$line" | awk '{print $7}')

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
        log "regular" "DEBUG" "if [ ! -d $fsTempMountPoint ]"
        ##if [ ! -d "$fsTempMountPoint" ]
        ##then
        ##    log "regular" "INFO" "Temporärer Mountpoint $fsTempMountPoint existiert nicht - Verzeichnis anlegen"
        ##    log "regular" "DEBUG" "mkdir $fsTempMountPoint"
        ##    mkdir $fsTempMountPoint
        ##    ### ToDo: ggf. Berechtigungen setzen, ggf. Abbruch bei Fehler
        ##    # chmod -R u=rwx,g+rw-x,o+rwx $mountpfad
        ##    # Script-Abbruch bei Fehler...
        ##else
        ##    log "regular" "INFO" "$fsTempMountPoint ist vorhanden."
        ##fi 

        pathExistsOrCreate $fsTempMountPoint
        result=$?
        if [ $result -eq 0 ]; then
            # Rückgabewert 0 - Ok
            echo "true"
        elif [ $result -eq 1 ]; then
            # Rückgabewert 1 - Fehler, Pfad ist nicht vorhanden - Abbruch
            echo "1"
            exit
        else
            # Rückgabewert 2 und höher - Fehler bei der Parameterübergabe
            echo "2"
            exit
        fi

        # Prüfen ob der Mountpoint leer ist
        log "regular" "DEBUG" "if [ -n $(ls -A $fsTempMountPoint) ]"
        ##if [ -n "$(ls -A $fsTempMountPoint)" ]
        ##then
        ##    log "regular" "INFO" "Mountpoint $fsTempMountPoint enthält Daten - löschen"
        ##    # Alles unterhalb des Mountpoint löschen
        ##    log "regular" "DEBUG" "find $fsTempMountPoint -mindepth 1 -delete"
        ##    find $fsTempMountPoint -mindepth 1 -delete
        ##    ### ToDo: Warnung bei Fehler... (kann notfalls im Nachgang händisch entfernt werden)
        ##else
        ##    log "regular" "INFO" "Verzeichnis ist leer."
        ##fi

        pathEmptyOrDelContent $fsTempMountPoint
        result=$?
        if [ $result -eq 0 ]; then
            # Rückgabewert 0 - Ok
            echo "0"
        elif [ $result -eq 1 ]; then
            # Rückgabewert 1 - Fehler, Verzeichnis nicht leer - Abfrage Abbruch/Weiter
            echo "1"
            ### ToDo: Abfrage bei Fehler ob weiter oder Abbruch
        else
            # Rückgabewert 2 oder höher - Fehler bei Parameterübergabe - Abbruch
            echo "2+"
            exit
        fi

        # In Mountpoint mounten
        log "regular" "DEBUG" "mount /dev/$lvmVgName/$lvmLvName $fsTempMountPoint"
        mount "/dev/$lvmVgName/$lvmLvName" "$fsTempMountPoint"

        log "regular" "DEBUG" "if [ \${QDIR:(-1)} == / ]"
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

        # mal schauen, was gemounted wird...
        mnt=$(mount)
        log "regular" "DEBUG" "mnt: .......................... $mnt"
        
        # Zielpfad im alten Mountpoint zusammensetzen...
        fsTgtPath="$fsOMP$fsTgt*"
        ### ToDo: .../* Slash vor *
        log "regular" "DEBUG" "fsTgtPath: .................... $fsTgtPath"

        
        ### ToDo: vorher prüfen, ob Quelle existiert, sonst rsync überspringen
        # Dateien vom source ins neue Filesystem kopieren
        log "regular" "DEBUG" "rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* $fsTgtPath* $fsTempMountPoint"
        # rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* "$fsOMP$fsTgt*" "$fsTempMountPoint"
        rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* $fsTgtPath $fsTempMountPoint
    fi

done <<<"$x"
log "regular" "INFO" "### End Loop2..."

echo "Taste drücken..."
read $x


# FSTAB IM NEUEN ROOT ANPASSEN
# ============================

fstab="$mntDst/etc/fstab"

log "regular" "DEBUG" "fstab: ....................... $fstab"

# prüfen, ob ein /boot Eintrag existiert - wenn nicht, evtl. abbruch
row=$(grep -E '^[^#].+\s\/boot\s{2,}ext[2-4]' $fstab)

log "regular" "DEBUG" "row: ......................... $row"

# prüfen ob row != "", sonst ist keine extra boot Partition vorhanden, was ggf die einrichtung des Bootloaders verkompliziert...
log "regular" "DEBUG" "if [ $row == \"\" ]"
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
log "regular" "DEBUG" "if [ $row != \"\" ]"
if [ "$row" != "" ]
then
    log "regular" "INFO" "Es wurde ein Eintrag für eine root-Partition gefunden"
    # Ergebnis in $row zerlegen in den Zeilentext...
    oldRoot=$(echo $row | awk -F':' '{print $2}')
    # ...und die Zeilennummer
    oldRootLine=$(echo $row | awk -F':' '{print $1}')

    # ersetzen von Zeile $oldRootLine mit '# $oldRoot'
    sed "$oldRootLine c \
    # $oldRoot" $fstab
else
    log "regular" "INFO" "Es wurde kein Eintrag für eine root-Partition gefunden"
    # wenn keine root-Partition vorhanden ist: Fehler und Abbruch.
    log "regular" "ERROR" "Kein Eintrag für root-Filesystem in $fstab gefunden. Script wird beendet."
    echo "FEHLER: Kein root-Filesystem-Eintrag in $fstab gefunden. Das Script wird abgebrochen."
    exit 2
fi


# NÄCHSTER LOOP: Logical Volumes in /etc/fstab eintragen
# ======================================================

x=$(echo -e "$nextLoop")
while read -r line 
do
    echo " ---> $line"
    lvmLvName=$(echo "$line" | awk '{print $1}')
    lvmLvSize=$(echo "$line" | awk '{print $2}')
    fsType=$(echo "$line" | awk '{print $3}')
    fsMountPoint=$(echo "$line" | awk '{print $4}')
    # fsTempMountPoint=$(echo "$line" | awk '{print $5}')
    fsTempMountPoint="$mntDst$fsMountPoint"
    fsUUID=$(echo "$line" | awk '{print $6}')
    fsMapper=$(echo "$line" | awk '{print $7}')

    # kein Mountpoint, dann auf "none" setzen (swap)
    if [ "$fsMountPoint" == "" ]; then $fsMountPoint="none"; fi
    fsOptions="defaults"
    fsDump="0"
    fsPass="2"
    isRoot="0"
    # bei swap-Filesystem Variablen $fsPass und $fsOptions abweichend vom Default-Wert belegen
    # bei root-Partition Variablen $fsPass und $fsOptions abweichend von Default-Wert belegen
    if [ "$fsType" == "swap" ] 
    then 
        fsOptions="sw" 
        fsPass="0"
    elif [ "$fsMountPoint" == "/" ] 
    then
        fsOptions="errors=remount-ro"
        fsPass="1"
        isRoot="1"
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

    # Prüfen ob root-Partition - dann unterhalb der auskommentierten Zeile einfügen    
    if [ "$isRoot" == "1" ]
    then
        # neue UID der root part anfügen
        sed "$oldRootLine a \
            $fsTabLine" $fstab
    # sonst ist es keine root-Partition - dann am Ende der Datei einfügen...
    else
        # Anzahl Zeilen ermitteln = letzte Zeile
        lastRowLine=$(cat $fstab | wc -l)
        # neue UID der xxx part anfügen
        sed "$lastRowLine a \
            $fsTabLine" $fstab
    fi
done <<<"$x"


# GRUB AKTUALISIEREN
# ==================

# /boot mounten...
mount "$fsSourceBootPartition" /mnt/root/boot

# Mounten der kritischen virtuellen Dateisysteme
for i in /dev /dev/pts /proc /sys /run; do mount -B $i /mnt/root$i; done

# Chroot into your normal system device:
chroot /mnt/root

# Reinstall GRUB 2 
grub-install "$fsSourceBootDrive"

# Recreate the GRUB 2 menu file (grub.cfg)
update-grub

# Exit chroot: CTRL-D on keyboard