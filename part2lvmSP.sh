#!/bin/bash

# part2lvmSP.sh
# v. 1.0.1  - 20210124  - mh    - logischer Ablauf vollständig
# v. 1.0.0  - 20210117  - mh    - part2lvmSP (Single Partition) - verschiebt ein Verzeichnis in ein Logical Volume
#                                 und passt die fstab in der root-Partition an
#                                 komplette Neuentwicklung   
# v. 0.0.2  - 20200811  - mh    - LVM einrichtung vollständig, ungetestet
# v. 0.0.1  - 20200811  - mh    - initiale Version
#
# Author: Mirko Härtwig

# ### Logging:
# # Funktionsbeschreibung
# Log DEBUG 'Funktionsbeschreibung'
# Log DEBUG 'Variable1'
# Log DEBUG 'Variable2'
# Log ...
# Funktionsaufruf Variable1 Variable2 ...
# Log DEBUG 'Ergebnis der Funktion...'

# ### Entwicklung der Funktion:
# Variablentabelle...
# # Variablenname:    Wert
# # Variablenname2:   Wert
# # Variablenname3:   Wert
# # ...
# Funktionsaufruf Var1 Var2 Var2 ...

# =================================================================================================
# Konstanten
# =================================================================================================
# rWARNING_xxx : return Codes WARNING ab 100 (Globale Fehlercodes)
# rWARNING_xxx : return Codes WARNING ab 150 (Script-spezifische Fehlercodes)

# rERROR_xxx : return Codes ERROR ab 200 (Globale Fehlercodes)
rERROR_IncludingFail=211

# rERROR_xxx : return Codes ERROR ab 250 (Script-spezifische Fehlercodes)


# ================================================================================================
# part2lvm-utils.sh einbinden...
# ================================================================================================

if [ -f ./part2lvm-utils.sh ] ;then
    . ./part2lvm-utils.sh
else
    echo "ERROR: ./part2lvm-utils.sh not available"
    exit $rERROR_IncludingFail
fi


# ================================================================================================
# part2lvm-vars.sh einbinden...
# ================================================================================================

if [ -f ./part2lvm-vars.sh ] ;then
    . ./part2lvm-vars.sh
else
    echo "ERROR: ./part2lvm-vars.sh not available"
    exit $rERROR_IncludingFail
fi


# =================================================================================================
# Logging - Einstellungen überschreiben
# =================================================================================================

LOGLEVEL="0"
ENABLE_LOG="1"
#Rund in Logging / Debug Mode only, means to print out log messages to STDOUT
DEBUG=0
LOGDIR="$(pwd)/log"
LOGFILE="$LOGDIR/$(date +%Y%m%d-%H%M%S)_part2lvmSP.log"


# =================================================================================================
# auf root-Recht prüfen
# =================================================================================================

checkRoot
result=$?
# Prüfen, ob $result -not_equal 0 (nicht root)
if [ $result -ne 0 ]; then

    # checkRoot hat nicht 0 zurückgegeben -> nicht root -> Abbruch
    exit $result
fi

### ===============================================================================================
### pv anlegen

# Prüfen, ob PV an /dev/sda3 existiert
# devPhysicalVolume:        /dev/sda3
pv=$(pvdisplay | grep 'PV Name' | grep "$devPhysicalVolume")
if [ $pv == "" ]; then

    # leer -> PV nicht gefunden -> PV muss angelegt werden
    # devPhysicalVolume:        /dev/sda3
    pvcreate "$devPhysicalVolume"
    result=$?
    # Prüfen, ob $result -not_equal 0 (Fehler beim Anlegen des PV)
    if [ $result -ne 0 ]; then

        # pvcreate hat nicht 0 zurückgegeben -> Fehler bei der Ausführung -> Abbruch
        log "regular" "ERROR" "main: ................................. Fehler $result (pvcreate)"
        exit $result
    fi
fi

### ===============================================================================================
### vg anlegen

# Prüfen, ob VG vg_debian existiert
# lvmVolumeGroup:           vg_debian
vg=$(vgdisplay | grep 'VG Name' | grep "$lvmVolumeGroup")
if [ $vg == "" ]; then

    # leer -> VG nicht gefunden -> VG muss angelegt werden
    # devPhysicalVolume:        /dev/sda3
    # lvmVolumeGroup:           vg_debian
    vgcreate "$lvmVolumeGroup" "$devPhysicalVolume"
    result=$?
    # Prüfen, ob $result -not_equal 0 (Fehler beim Anlegen der VG)
    if [ $result -ne 0 ]; then

        # vgcreate hat nicht 0 zurückgegeben -> Fehler bei der Ausführung -> Abbruch
        log "regular" "ERROR" "main: ................................. Fehler $result (vgcreate)"
        exit $result
    fi
else

    # nicht leer -> VG vorhanden -> VG nicht anlegen, aber prüfen, dass in /dev/sda3 angelegt

    # ToDo: Prüfung -> sonst Hinweis und Abbruch
fi

### ===============================================================================================
### lv anlegen

# Prüfen, ob LV lv_home existiert
# lvmLogicalVolume:      lv_home
lv=$(lvdisplay | grep 'LV Name' | grep "$lvmLogicalVolume")
if [ $lv == "" ], then

    # leer -> LV nicht gefunden -> LV muss angelegt werden
    # lvmSize:              20G
    # lvmLogicalVolume:     lv_home
    # lvmVolumeGroup:       vg_debian
    lvcreate -L "$lvmSize" -n "$lvmLogicalVolume" "$lvmVolumeGroup"
    result=$?
    # Prüfen, ob $result -not_equal 0 (Fehler beim Anlegen des LV)
    if [ $result -ne 0 ]; then

        # lvcreate hat nicht 0 zurückgegeben -> Fehler bei der Ausführung -> Abbruch
        log "regular" "ERROR" "main: ................................. Fehler $result (lvcreate)"
        exit $result
    fi
else

    # nicht leer -> LV vorhanden -> LV nicht anlegen, aber prüfen, dass in vg_debian angelegt

    # ToDo: Prüfung -> sonst Hinweis und Abbruch
fi

### ===============================================================================================
### Dateisystem anlegen

# Prüfen des Dateisystemtyps
# fsType:      ext4
if [ "$fsType" == "ext4" ]; then

    # Dateisystem = ext4 -> ext4 auf dem LV anlegen
    # lvmVolumeGroup:      vg_debian
    # lvmLogicalVolume:    lv_home
    mkfs.ext4 "/dev/$lvmVolumeGroup/$lvmLogicalVolume"
    result=$?
    # Prüfen, ob $result -not_equal 0 (Fehler beim Anlegen des Dateisystems)
    if [ $result -ne 0 ]; then

        # mkfs.ext4 hat nicht 0 zurückgegeben -> Fehler bei der Ausführung -> Abbruch
        log "regular" "ERROR" "main: ................................. Fehler $result (mkfs.ext4)"
        exit $result
    fi
elif [ "$fsType" == "swap" ]; then

    # Dateisystem = swap -> swap auf dem LV anlegen
    # lvmVolumeGroup:      vg_debian
    # lvmLogicalVolume:    lv_swap
    mkswap "/dev/$lvmVolumeGroup/$lvmLogicalVolume"
    result=$?
    # Prüfen, ob $result -not_equal 0 (Fehler beim Anlegen des Swap-Dateisystems)
    if [ $result -ne 0 ]; then

        # mkswap hat nicht 0 zurückgegeben -> Fehler bei der Ausführung -> Abbruch
        log "regular" "ERROR" "main: ................................. Fehler $result (mkswap)"
        exit $result
    fi
else

    # Dateisystem nicht unterstützt -> Abbruch
    log "regular" "ERROR" "main: ................................. Fehler $rERROR_FilesystemNotSupported (Nicht unterstütztes Dateisystem)"
    exit $rERROR_FilesystemNotSupported
fi

### -----------------------------------------------------------------------------------------------
### Die folgenden Aktionen nur ausführen, wenn kein swap-FS geliefert wird

# Prüfen, ob kein swap-FS geliefert wird
# fsType:      swap        (filesystem)
if [ "$fsType" != "swap" ]; then

    ### ===========================================================================================
    ### Quell-Dateisystem mounten

    ### fstab aus gemounteter Source-Partition lesen -> root-Partition holen, source dismounten und
    ### root-partition wie ins fstab gelesen mounten

    # ToDo: Quell-Dateisystem komplett aus der fstab ermitteln und mounten! Damit ist parent
    #       obsolete.

    # Mounten
    # varname:      /dev/sda2       Quell-Partition
    # varname:      /mnt/src
    prepareMountAndTest "/dev/sda2" "/mnt/src"
    result=$?
    if [ $result -eq 0 ]; then

        # Rückgabewert 0 -> erfolgreich gemounted
        echo "toll - Source gemounted"
    else

        # Rückgabewert > 0 -> Fehler beim Mounten der Source Partition -> Abbruch
        exit $result
    fi

    ### ===========================================================================================
    ### Ziel-Dateisystem mounten

    # Mounten
    # varname:      vg_debian
    # varname:      lv_home
    # varname:      /dev/mapper/vg_debian-lv_home       Ziel-Partition
    # varname:      /mnt/dst
    prepareMountAndTest "/dev/mapper/vg_debian-lv_home" "/mnt/dst"
    result=$?
    if [ $result -eq 0 ]; then

        # Rückgabewert 0 -> erfolgreich gemounted
        echo "toll - Ziel erfolgreich gemounted"
    else

        # Rückgabewert > 0 -> Fehler, Abbruch
        exit $result
    fi

    ### ===========================================================================================
    ### rsync Src -> Dst

    # Prüfen, ob Zielpfad existiert (?)
    # varname:      /mnt/src        (source)
    # varname:      /home           (mountpoint)
    # ziel = /mnt/src/home
    if [ -d "/mnt/src/home" ]; then

        # Quell-Verzeichnis existiert -> rsync
        # varname:      /mnt/src        (source)
        # varname:      /home           (mountpoint)
        # varname:      /mnt/dst        (destination)
        rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* "/mnt/src/home" "/mnt/dst"
        result=$?
        if [ $result -eq 0 ]; then

            # Result = 0 -> rsync ohne Fehler abgeschlossen
        else

            # Result > 0 -> rsync mit Fehler abgeschlossen -> Abbruch
            exit 1
        fi
    fi


    ### ===========================================================================================
    ### Destination dismounten

    # Ziel-Mountpoint dismounten
    # varname:      vg_debian
    # varname:      lv_home
    # varname:      /dev/mapper/vg_debian-lv_home       Ziel-Partition
    # varname:      /mnt/dst
    umount "/mnt/dst"
    result=$?
    if [ $result -eq 0 ]; then

        # Rückgabewert 0 -> Befehlt erfolgreich ausgeführt -> Ergebnis gegenprüfen
        found=$(mount | grep "/mnt/dst " | grep "/dev/mapper/vg_debian-lv_home ")
        if [ "$found" == "" ]; then

            # keinen Mount-Eintrag gefunden -> erfolgreich dismounted
            echo "toll - Dismount erfolgreich"
        else

            # Mount-Eintrag gefunden -> Dismount nicht erfolgreich -> Abbruch
            echo "mist"
            exit 1
        fi
    else

        # Rückgabewert > 0 -> fehler beim dismount
        echo "mist"
        exit 1
    fi


    ### ===========================================================================================
    ### Neues LV in die Source-Partition einhängen, der Mountpoint wird dabei ggf. angelegt/geleert

    # Das neue LV wird an dem Mountpoint auf der Source-Partition eingehängt. Der Mountpoint wird 
    # vorher angelegt und/bzw. geleert

    # Mounten
    # varname:      vg_debian
    # varname:      lv_home
    # varname:      /dev/mapper/vg_debian-lv_home       Ziel-Partition
    # varname:      /mnt/src
    # varname:      /home
    # varname:      /mnt/src/home
    prepareMountAndTest "/dev/mapper/vg_debian-lv_home" "/mnt/src/home"
    result=$?
    if [ $result -eq 0 ]; then

        # Rückgabewert 0 -> erfolgreich gemounted
        echo "toll - Ziel erfolgreich gemounted"
    else

        # Rückgabewert > 0 -> Fehler, Abbruch
        exit $result
    fi
fi
### -----------------------------------------------------------------------------------------------


### ===============================================================================================
### fstab eintragen

# Hat soweit alles funktioniert, wird ein Eintrag in der fstab angelegt...

# Variablen vorbelegen
fsOptions="defaults"
fsDump="0"
fsPass="2"
isRoot="0"

# bei swap-Filesystem Variablen $fsPass und $fsOptions abweichend vom Default-Wert belegen
# bei root-Partition Variablen $fsPass und $fsOptions abweichend von Default-Wert belegen
if [ "$fsType" == "swap" ]; then

    log "regular" "INFO" "fsType is SWAP..." 
    fsOptions="sw" 
    fsPass="0"
    
    log "regular" "DEBUG" "fsOptions: .............................. $fsOptions"
    log "regular" "DEBUG" "fsPass: ................................. $fsPass"
elif [ "$fsMountPoint" == "/" ]; then

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

# fstab in eine temporäre Datei kopieren
cp $fstab fstab.tmp

# Prüfen, ob root-Partition    
if [ "$isRoot" == "1" ]; then

    # Ist root-Partition -> unterhalb der auskommentierten Zeile einfügen (OBSOLETE!!!)
    log "regular" "INFO" "Mountpoint für Root Partition..."
    # neue UID unter der der auskommentierten, alten root partition anfügen
    
    cat fstab.tmp | sed "$oldRootLine a \
        $fsTabLine" > $fstab
    fstext=$(cat "$fstab")
    log "regular" "DEBUG" "$fstext"
else

    # Keine root-Partition -> am Ende der Datei einfügen
    log "regular" "INFO" "keine Root Partition..."
    # Anzahl Zeilen ermitteln = letzte Zeile
    lastRowLine=$(cat $fstab | wc -l)
    # neue UID der xxx part anfügen
    
    cat fstab.tmp | sed "$lastRowLine a \
        $fsTabLine" > $fstab
    fstext=$(cat "$fstab")
    log "regular" "DEBUG" "$fstext"
fi

# temporäre fstab löschen
del fstab.tmp
