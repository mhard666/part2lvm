#!/bin/bash

# part2lvm.sh
# v. 0.0.2  - 20200811  - mh    - LVM einrichtung vollständig, ungetestet
# v. 0.0.1  - 20200811  - mh    - initiale Version
#
# Author: Mirko Härtwig

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

log "regular" "INFO" "Script $0 gestartet."

# Dieses Script muss als root ausgeführt werden!
## ToDo: Auf root testen...

# Variablen...
fsSourceRootDrive="/dev/sda"
fsSourceBootDrive="/dev/sda"
fsSourceRootPartition="/dev/sda2"
fsSourceBootPartition="/dev/sda1"

# LVM AUF DER NEUEN PARTITION EINRICHTEN
# ======================================

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
lvmLogicalVolumeData='lv_root 10G ext4 / /mnt/dst
lv_swap 16G swap
lv_home 20G ext4 /home /mnt/dst/home
lv_opt 2G ext4 /opt /mnt/dst/opt
lv_var 5G ext4 /var /mnt/dst/var
lv_var_log 5G ext4 /var/log /mnt/dst/var/log
lv_var_tmp 5G ext4 /var/tmp /mnt/dst/var/tmp
lv_var_lib_postgresql 40G ext4 /var/lib/postgresql'

#zum testen...
lvmLogicalVolumeData='lv_root 3G ext4 / /mnt/dst
lv_swap 1G swap
lv_home 2G ext4 /home /mnt/dst/home
lv_opt 1G ext4 /opt /mnt/dst/opt
lv_var 2G ext4 /var /mnt/dst/var
lv_var_log 2G ext4 /var/log /mnt/dst/var/log
lv_var_tmp 2G ext4 /var/tmp /mnt/dst/var/tmp
lv_var_lib_postgresql 2G ext4 /var/lib/postgresql'

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
    fsTempMountPoint=$(echo "$line" | awk '{print $5}')

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
    if [ "$fsType" == "ext4" ]
    then
        log "regular" "INFO" "Filesystem ist ext4"
        # Dateisysteme auf den LVs anlegen
        log "regular" "DEBUG" "mkfs.ext4 /dev/$lvmVgName/$lvmLvName"
        mkfs.ext4 "/dev/$lvmVgName/$lvmLvName"
    elif [ "$fsType" == "swap" ]
    then
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

    # Wenn nextLoop nicht leer ist erstmal einen Zeilenumbruch dranhängen...
    if [ "$nextLoop" != "" ] 
    then
        nextLoop+="\n"
    fi

    # Hier die aufbereiteten Zeilen hin, Spalten jeweils Leerzeichen-separiert
    ### ToDo: Leere Variablen mit Dummy-Werten füllen, sonst gibt es probleme bei der Auswertung der Parameter im nächsten Loop!!!
    nextLoop+="$lvmLvName $lvmLvSize $fsType $fsMountPoint $fsTempMountPoint $fsUUID $fsMapper"


done <<<"$lvmLogicalVolumeData"
log "regular" "INFO" "### End Loop1..."


# NÄCHSTER LOOP: Neues Filesystem mounten und altes dahin syncen
# ==============================================================

# MountPoint für QuellFileSystem
fsOMP="/mnt/src"

# Prüfen ob Mountpoint vorhanden, wenn nicht Verzeichnis anlegen, wenn ja, 
# prüfen ob Verzeichnis leer, wenn nicht, leeren...
log "regular" "DEBUG" "if [ ! -d $fsOMP ]"
if [ ! -d "$fsOMP" ]
then
    log "regular" "INFO" "Mountverzeichnis $fsOMP existiert nicht"
    log "regular" "DEBUG" "mkdir $fsOMP"
    mkdir "$fsOMP"
    ### ToDo: ggf. Berechtigungen setzen, ggf. Abbruch bei Fehler
    # chmod -R u=rwx,g+rw-x,o+rwx $mountpfad
    # Script-Abbruch bei Fehler...
else
    log "regular" "INFO" "Verzeichnis $fsOMP existiert."
fi 

# Prüfen ob der Mountpoint leer ist
log "regular" "DEBUG" "if [ -n $(ls -A $fsOMP) ]"
if [ -n "$(ls -A $fsOMP)" ]
then
    log "regular" "INFO" "Mountverzeichnis $fsOMP ist nicht leer - löschen"
    # Alles unterhalb des Mountpoint löschen
    log "regular" "DEBUG" "find $fsOMP -mindepth 1 -delete"
    find "$fsOMP" -mindepth 1 -delete
    ### ToDo: ggf. Warnung bei Fehler
    # Warnung bei Fehler... (kann notfalls im Nachgang händisch entfernt werden)
else
    log "regular" "INFO" "Verzeichnis $fsOMP ist leer."
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
    fsTempMountPoint=$(echo "$line" | awk '{print $5}')
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
        # prüfen ob Verzeichnis leer, wenn nicht, leeren...
        log "regular" "DEBUG" "if [ ! -d $fsTempMountPoint ]"
        if [ ! -d "$fsTempMountPoint" ]
        then
            log "regular" "INFO" "Temporärer Mountpoint $fsTempMountPoint existiert nicht - Verzeichnis anlegen"
            log "regular" "DEBUG" "mkdir $fsTempMountPoint"
            mkdir $fsTempMountPoint
            ### ToDo: ggf. Berechtigungen setzen, ggf. Abbruch bei Fehler
            # chmod -R u=rwx,g+rw-x,o+rwx $mountpfad
            # Script-Abbruch bei Fehler...
        else
            log "regular" "INFO" "$fsTempMountPoint ist vorhanden."
        fi 

        # Prüfen ob der Mountpoint leer ist
        log "regular" "DEBUG" "if [ -n $(ls -A $fsTempMountPoint) ]"
        if [ -n "$(ls -A $fsTempMountPoint)" ]
        then
            log "regular" "INFO" "Mountpoint $fsTempMountPoint enthält Daten - löschen"
            # Alles unterhalb des Mountpoint löschen
            log "regular" "DEBUG" "find $fsTempMountPoint -mindepth 1 -delete"
            find $fsTempMountPoint -mindepth 1 -delete
            ### ToDo: Warnung bei Fehler... (kann notfalls im Nachgang händisch entfernt werden)
        else
            log "regular" "INFO" "Verzeichnis ist leer."
        fi

        # In Mountpoint mounten
        log "regular" "DEBUG" "mount /dev/$lvmVgName/$lvmLvName $fsTempMountPoint"
        mount "/dev/$lvmVgName/$lvmLvName" "$fsTempMountPoint"

        ### ToDo: Slash anhängen wenn letztes zeichen kein Slash ist
        log "regular" "DEBUG" "if [ \${QDIR:(-1)} == / ]"
        if [ "${fsMountPoint:(-1)}" == "/" ]; then
            log "regular" "INFO" "Slash am Ende"
            echo Slash am Ende!
            fsTgt="$fsMountPoint"
        else
            log "regular" "INFO" "Kein Slash am Ende - / anhängen"
            echo kein slash am ende
            fsTgt="$fsMountPoint/" # Nur wenn letztes Zeichen nicht / ist
        fi
    
        log "regular" "DEBUG" "fsTgt: ........................ $fsTgt"

        # mal schauen, was gemounted wird...
        mnt=$(mount)
        log "regular" "DEBUG" "mnt: .......................... $mnt"
        
        # Zielpfad im alten Mountpoint zusammensetzen...
        fsTgtPath=$fsOMP$fsTgt
        log "regular" "DEBUG" "fsTgtPath: .................... $fsTgtPath"

        # Dateien vom source ins neue Filesystem kopieren
        log "regular" "DEBUG" "rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* $fsTgtPath* $fsTempMountPoint"
        # rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* "$fsOMP$fsTgt*" "$fsTempMountPoint"
        rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* "$fsTgtPath*" "$fsTempMountPoint"
    fi

done <<<"$x"
log "regular" "INFO" "### End Loop2..."

echo "Taste drücken..."
read $x


# FSTAB IM NEUEN ROOT ANPASSEN
# ============================

# prüfen, ob ein /boot Eintrag existiert - wenn nicht, evtl. abbruch
row=$(grep -E '^[^#].+\s\/boot\s{2,}ext[2-4]' /etc/fstab)

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
row=$(grep -n -E '^[^#].+\s\/\s{2,}(ext[2-4]|xfs|btrfs)' /etc/fstab)

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
    # $oldRoot" /etc/fstab
else
    log "regular" "INFO" "Es wurde kein Eintrag für eine root-Partition gefunden"
    # wenn keine root-Partition vorhanden ist: Fehler und Abbruch.
    log "regular" "ERROR" "Kein Eintrag für root-Filesystem in /etc/fstab gefunden. Script wird beendet."
    echo "FEHLER: Kein root-Filesystem-Eintrag in /etc/fstab gefunden. Das Script wird abgebrochen."
    Exit 2
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
    fsTempMountPoint=$(echo "$line" | awk '{print $5}')
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
            $fsTabLine" /etc/fstab
    # sonst ist es keine root-Partition - dann am Ende der Datei einfügen...
    else
        # Anzahl Zeilen ermitteln = letzte Zeile
        lastRowLine=$(cat /etc/fstab | wc -l)
        # neue UID der xxx part anfügen
        sed "$lastRowLine a \
            $fsTabLine" /etc/fstab
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