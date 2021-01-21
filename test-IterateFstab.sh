#!/bin/bash

# test-IterateFstab.sh
#
# iteriert die fstab um alle Einträge zu mounten
#
# v. 0.0.1  - 20200811  - mh    - initiale Version
#
# Author: Mirko Härtwig


# =========================================================
# Funktion:     mountFstab()
# Aufgabe:      iteriert /etc/fstab und mounted alle
#               relevanten Einträge in einem temporären
#               Mountpoint
# Parameter:    $1 Pfad zur fstab
#               $2 Mountpoint
# Return:       0: Ok
#               2: Wenn Fehler in Parameterübergabe
# Echo:         String
# =========================================================
function mountFstab {
    # Parameter prüfen
    if [ $# -lt 2 ]
    then
        log "regular" "ERROR" "FUNC: mountFstab(): Fehler bei Parameterübergabe"
        return $rERROR_WrongParameters
    fi

    # Übergabeparameter abholen
    mF_fstab=$1
    mF_mountpoint=$2


    # Alle Einträge der /etc/fstab liefern, die mit U(UID) oder /(dev/...) beginnen und Filesystem
    # ext2, ext3 oder ext4 sind.
    # line=$(grep ^[U\/] /etc/fstab | grep '.ext[2-4].')

    # Alle Einträge der /etc/fstab liefern, ausser Kommentare, swap, iso9660, udf
    line=$(grep -v '^#' "$mF_fstab" | grep -v '.swap.' | grep -v 'udf' | grep -v 'iso9660')
    
    # Effektiv kann die liste noch sortiert werden nach Spalte 2 (Mountpoint)
    # line=$(grep -v '^#' /etc/fstab | grep -v '.swap.' | grep -v 'udf' | grep -v 'iso9660' | sort -k 2)

    # Alle Zeilen in einer Schleife durchlaufen...
    while read entry
    do

        # Zeile ausgeben...
        echo ''
        echo $entry 

        # in Einzelbestandteile zerlegen
        uuid=""
        device=$(echo $entry | awk '{print $1}')    # Gerät
        mountpoint=$(echo $entry | awk '{print $2}')    # Mountpoint
        filesystem=$(echo $entry | awk '{print $3}')    # Filesystem

        echo $device
        echo $mountpoint
        echo $filesystem

        uuid=$(echo ${device} | grep '^UUID' | cut -d = -f 2)   # Geräte mit UUID, UUID separieren
        echo $uuid
        if [ "$uuid" != "" ]; then

            # wenn $uuid einen Wert enthält (eine UUID) -> prüfen, ob für diese UUID ein Gerät existiert
            if [ -h /dev/disk/by-uuid/$uuid ];then

                # Gerät existiert, mit UUID mounten
                echo $(grep $uuid /etc/fstab)  ..... found, mounting
                echo mount $uuid $mF_mountpoint$mountpoint
            else

                # UUID geliefert aber UUID existiert nicht als Gerät -> Skip
                echo ""
            fi
        else

            # keine UUID geliefert, sondern Gerätepfad -> Mit Gerätepfad mounten
            echo "mount $device $mF_mountpoint$mountpoint"
        fi
    done <<<"$line"


}

mountFstab "/etc/fstab" "/mnt/src"

# zum Testen im Rettungssystem alles mounten, chroot, testen mit 'findmnt --verify --verbose'