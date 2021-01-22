#!/bin/bash

# test-IterateFstab.sh
#
# iteriert die fstab um alle Einträge zu mounten
#
# v. 0.1.1  - 20210121. - mh    - getFstab hinzugefügt
# v. 0.0.1  - 20200811  - mh    - initiale Version
#
# Author: Mirko Härtwig

# rERROR_xxx : return Codes ERROR ab 2000
rERROR_RunNotAsRoot=2000
rERROR_WrongParameters=2001
rERROR_FileNotFound=2002
rERROR_PathNotExist=2010
rERROR_IncludingFail=2011
rERROR_NoRootEntryFstab=2012

# =========================================================
# Funktion:     getFstab()
# Aufgabe:      holt /etc/fstab von der root-Partition
#               und legt sie im Live-System ab. Dazu wird
#               die root-Partition gemounted, die Datei
#               kopiert, anschließend die root-Partition
#.              wieder dismounted
# Parameter:    $1 root-Partition
#               $2 Mountpoint
#               $3 Zielverzeichnis
# Return:       0:    Ok
#               2001: Wenn Fehler in Parameterübergabe
# Echo:         String
# =========================================================
function getFstab {
    # Parameter prüfen
    if [ $# -lt 3 ]
    then
        log "regular" "ERROR" "FUNC: mountFstab(): Fehler bei Parameterübergabe"
        return $rERROR_WrongParameters
    fi

    # Übergabeparameter abholen
    gF_root=$1
    gF_mountpoint=$2
    gF_destination=$3

    # Prüfen, ob Mountpoint existiert
    if [ -d $gF_mountpoint ]; then

        # Verzeichnis für Mountpoint existiert -> root mounten
        mount $gF_root $gF_mountpoint

        # Prüfen, ob das Zielverzeichnis existiert
        if [ -d $gF_destination ]; then

            # Zielverzeichnis existiert -> Prüfen, ob fstab existiert
            if [ -f "$gF_mountpoint/etc/fstab" ]; then

                # fstab vorhanden -> fstab kopieren
                cp "$gF_mountpoint/etc/fstab" "$gF_destination"

                # und root dismounten
                umount $gF_root
            else

                # fstab nicht gefunden
                echo "fstab nicht gefunden"
                return $rERROR_FileNotFound
            fi
        else

            # Zielverzeichnis nicht vorhanden
            echo "Zielverzeichnis nicht vorhanden"
            return $rERROR_PathNotExist
        fi
    else

        # Mountpoint nicht vorhanden
        echo "Mountpoint nicht vorhanden"
        return $rERROR_PathNotExist
    fi
    return 0
}


# =========================================================
# Funktion:     mountFstab()
# Aufgabe:      iteriert /etc/fstab und mounted alle
#               relevanten Einträge in einem temporären
#               Mountpoint
# Parameter:    $1 Pfad zur fstab
#               $2 Mountpoint
# Return:       0:    Ok
#               2001: Wenn Fehler in Parameterübergabe
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
    line=$(grep -v '^#' "$mF_fstab" | grep -v '.swap.' | grep -v 'udf' | grep -v 'iso9660' | awk '{print $2}' | sort)

    # Alle Einträge der /etc/fstab liefern, ausser Kommentare, swap, iso9660, udf
    # line=$(grep -v '^#' "$mF_fstab" | grep -v '.swap.' | grep -v 'udf' | grep -v 'iso9660')
    
    # Effektiv kann die liste noch sortiert werden nach Spalte 2 (Mountpoint)
    # line=$(grep -v '^#' /etc/fstab | grep -v '.swap.' | grep -v 'udf' | grep -v 'iso9660' | sort -k 2)

    # Alle Zeilen in einer Schleife durchlaufen...
    while read entry
    do

        # Zeile ausgeben...
        echo ''
        echo $entry 

        # in Einzelbestandteile zerlegen
        # $entry liefert den Mountpoint, Eintrag in der fstab suchen und diese Zeile zurückgeben
        r=$(grep "$entry " "$mF_fstab")

        # Prüfen, ob $r kein leerer String ist
        if [ "r" != "" ]; then

#            umount "$mp"

            uuid=""
            device=$(echo $r | awk '{print $1}')    # Gerät
            mountpoint=$(echo $r | awk '{print $2}')    # Mountpoint
            filesystem=$(echo $r | awk '{print $3}')    # Filesystem

            echo $device
            echo $mountpoint
            echo $filesystem

            uuid=$(echo ${device} | grep '^UUID' | cut -d = -f 2)   # Geräte mit UUID, UUID separieren
            echo $uuid
            if [ "$uuid" != "" ]; then

                # wenn $uuid einen Wert enthält (eine UUID) -> prüfen, ob für diese UUID ein Gerät existiert
                if [ -h /dev/disk/by-uuid/$uuid ]; then

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
        fi
    done <<<"$line"
    return 0
}


# =========================================================
# Funktion:     umountFstab()
# Aufgabe:      iteriert /etc/fstab rückwerts und 
#               dismounted alle Einträge, die gemounted 
#               sind
# Parameter:    $1 Pfad zur fstab
#               $2 Mountpoint
# Return:       0:    Ok
#               2001: Wenn Fehler in Parameterübergabe
# Echo:         String
# =========================================================
function umountFstab {
    # Parameter prüfen
    if [ $# -lt 2 ]
    then
        log "regular" "ERROR" "FUNC: mountFstab(): Fehler bei Parameterübergabe"
        return $rERROR_WrongParameters
    fi

    # Übergabeparameter abholen
    uF_fstab=$1
    uF_mountpoint=$2


    # Alle Einträge der /etc/fstab liefern, die mit U(UID) oder /(dev/...) beginnen und Filesystem
    # ext2, ext3 oder ext4 sind.
    # line=$(grep ^[U\/] /etc/fstab | grep '.ext[2-4].')

    # alle gemounteten Laufwerke ausgeben, Mountpoints extrahieren, Mountpoints filtern, 
    # die den Basismountpoint enthalten und diese sortieren
    line=$(mount | awk '{print $3}' | grep "$uFmountpoint" | sort -r)

    ### Alle Einträge der /etc/fstab liefern, ausser Kommentare, swap, iso9660, udf
    ### line=$(grep -v '^#' "$mF_fstab" | grep -v '.swap.' | grep -v 'udf' | grep -v 'iso9660')
    
    ### Effektiv kann die liste noch sortiert werden nach Spalte 2 (Mountpoint)
    ### line=$(grep -v '^#' /etc/fstab | grep -v '.swap.' | grep -v 'udf' | grep -v 'iso9660' | sort -r -k 2)

    # Alle Zeilen in einer Schleife durchlaufen...
    while read entry
    do

        # Zeile ausgeben...
        echo ''
        echo $entry 

        # $uF_mountpoint vom gefundenen Mountpoint abtrennen
        # bsp.: $uF_mountpoint=/mnt/src ; $entry=/mnt/src/home ; bleibt: /home
        # ${uF_Mountpoint}+1 = Offset
        # ${entry:OFFSET} = liefert $entry ab dem Offset, also den Gesamtmountpoint ohne den Basismountpoint
        mp=${entry:${#uF_mountpoint}+1}

        # Prüfen, ob es für den Mountpoint einen Eintrag in der fstab gibt
        # liefere die Zeile aus der fstab, in der der extrahierte Mountpoint ($mp) gefunden wird
        r=$(grep "$mp " "$uF_fstab")

        # Prüfen, ob $r kein leerer String ist
        if [ "r" != "" ]; then

            umount "$mp"
        fi
    done <<<"$line"
    return 0
}

mountFstab "/etc/fstab" "/mnt/src"

# zum Testen im Rettungssystem alles mounten, chroot, testen mit 'findmnt --verify --verbose'