#!/bin/bash

# part2lvmSP.sh
# v. 1.0.0  - 20210117. - mh    - part2lvmSP (Single Partition) - verschiebt ein Verzeichnis in ein Logical Volume
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


### ===============================================================================================
### pv anlegen

# Prüfen, ob PV an /dev/sda3 existiert
result=$(pvdisplay | grep 'PV Name' | grep '/dev/sda3')
if [ $result == "" ]; then

    # leer -> PV nicht gefunden -> PV muss angelegt werden
    # varname:      /dev/sda3
    pvcreate "/dev/sda3"

    # ToDo: Rückgabewert prüfen!
fi

### ===============================================================================================
### vg anlegen

# Prüfen, ob VG vg_debian existiert
result=$(vgdisplay | grep 'VG Name' | grep 'vg_debian')
if [ $result == "" ]; then

    # leer -> VG nicht gefunden -> VG muss angelegt werden
    # varname:      /dev/sda3
    # varname:      vg_debian
    vgcreate "vg_debian" "/dev/sda3"

    # ToDo: Rückgabewert prüfen!
else

    # nicht leer -> VG vorhanden -> VG nicht anlegen, aber prüfen, dass in /dev/sda3 angelegt

    # ToDo: Prüfung -> sonst Hinweis und Abbruch
fi

### ===============================================================================================
### lv anlegen

# Prüfen, ob LV lv_home existiert
result=$(lvdisplay | grep 'LV Name' | grep 'lv_home')
if [ $result == "" ], then

    # leer -> LV nicht gefunden -> LV muss angelegt werden
    # varname:      20G
    # varname:      lv_home
    # varname:      vg_debian
    lvcreate -L "20G" -n "lv_home" "vg_debian"

    # ToDo: Rückgabewert prüfen!
else

    # nicht leer -> LV vorhanden -> LV nicht anlegen, aber prüfen, dass in vg_debian angelegt

    # ToDo: Prüfung -> sonst Hinweis und Abbruch

### ===============================================================================================
### Dateisystem anlegen

# Prüfen des Dateisystemtyps
# varname:      ext4
if [ "ext4" == "ext4" ]; then

    # Dateisystem = ext4 -> ext4 auf dem LV anlegen
    # varname:      vg_debian
    # varname:      lv_home
    mkfs.ext4 "/dev/vg_debian/lv_home"

    # ToDo: Rückgabewert prüfen!
elif [ "$var" == "swap" ]; then

    # Dateisystem = swap -> swap auf dem LV anlegen
    # varname:      vg_debian
    # varname:      lv_swap
    mkswap "/dev/vg_debian/lv_swap"

    # ToDo: Rückgabewert prüfen!
else

    # Dateisystem nicht unterstützt -> Abbruch
    exit 1
fi

### -----------------------------------------------------------------------------------------------
### Die folgenden Aktionen nur ausführen, wenn kein swap-FS geliefert wird

# Prüfen, ob kein swap-FS geliefert wird
# varname:      swap        (filesystem)
if [ "swap" != "swap" ]; then

    ### ===========================================================================================
    ### Quell-Dateisystem mounten

    # ToDo: Quell-Dateisystem komplett aus der fstab ermitteln und mounten! Damit ist parent
    #       obsolete.

    # Prüfen, ob der Mountpoint existiert, ggf. anlegen
    # varname:      /mnt/src
    pathExistsOrCreate "/mnt/src"
    result=$?
    if [ $result -eq 0 ]; then

        # Rückgabewert 0 -> Verzeichnis existiert oder wurde angelegt
    else

        # Rückgabewert > 0 -> Fehler beim Anlegen des Verzeichnisses -> Abbruch
        exit 1
    fi

    # Prüfen ob Mountpoint leer ist, ggf. löschen
    # varname:      /mnt/src
    pathEmptyOrDelContent "/mnt/src"
    result=$?
    if [ $result -eq 0 ]; then

        # Rückgabewert 0 -> Verzeichnis existiert oder wurde angelegt
    elif [ $result -eq $rWARNING_PathNotEmpty ]; then

        # Rückgabewert = $rWARNING_PathNotEmpty -> Abfrage Abbruch/Weiter (wenn weiter, wird trotzdem 
        # in das Verzeichnis gemounted)

        # ToDo: Abfrage Abbruch/Weiter
    else

        # Anderer Rückgabewert > 0 -> Fehler aufgetreten -> Abbruch
        exit 1
    fi

    # Mounten
    # varname:      /dev/sda2       Quell-Partition
    # varname:      /mnt/src
    mount "/dev/sda2" "/mnt/src"
    result=$?
    if [ $result -eq 0 ]; then

        # Rückgabewert 0 -> erfolgreich gemounted -> Gegenprüfung

        # ToDo: Gegenprüfung
    else

        # Rückgabewert > 0 -> Fehler beim Mounten der Source Partition -> Abbruch
    fi

    ### ===========================================================================================
    ### Ziel-Dateisystem mounten

    # ToDo Analog Source...

    ### ===========================================================================================
    ### Eltern-Dateisystem mounten

    # Prüfen, ob Parent = Source
    # varname:      /dev/sda2       (parent)
    # varname:      /dev/sda2       (source)
    if [ "/dev/sda2" != "/dev/sda2" ]; then

        # Parent != Source -> Parent mounten

        # ToDo: Analog Source
    else

        # Parent == Source -> nichts mounten
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
        rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* "/mnt/src/home" "/mnt/dst/home"
        result=$?
        if [ $result -eq 0 ]; then

            # Result = 0 -> rsync ohne Fehler abgeschlossen
        else

            # Result > 0 -> rsync mit Fehler abgeschlossen -> Abbruch
            exit 1
        fi
    fi

    ### ===========================================================================================
    ### Mountpoint im Parent anlegen/leeren



fi
### -----------------------------------------------------------------------------------------------

# fstab eintragen
