#!/bin/bash

# part2lvm.sh
# v. 0.0.2  - 20200811  - mh    - LVM einrichtung vollständig, ungetestet
# v. 0.0.1  - 20200811  - mh    - initiale Version
#
# Author: Mirko Härtwig

# root-Modus wechseln
sudo su

# LVM AUF DER NEUEN PARTITION EINRICHTEN
# ======================================

# Physical Volume auf der neuen Partition (sda3) anlegen
lvmPvDevice="/dev/sda3"
pvcreate $lvmPvDevice

# Volume Group im Physical Volume anlegen
lvmVgName="vg_debian"
vgcreate $lvmVgName $lvmPvDevice

# Logical Volumes anlegen
# lvmLvName lvmLvSize fsType fsMountPoint fsTempMountPoint
lvmLogicalVolumeData='lv_root 10G ext4 / /mnt/dst
lv_swap 16G swap
lv_home 20G ext4 /home /mnt/dst/home
lv_opt 2G ext4 /opt /mnt/dst/opt
lv_var 5G ext4 /var /mnt/dst/var
lv_var_log 5G ext4 /var/log /mnt/dst/var/log
lv_var_tmp 5G ext4 /var/tmp /mnt/dst/var/log
lv_var_lib_postgresql 40G ext4' /var/lib/postgresql

# Variable zur Zeilenweisen Aufbereitung der Ergebnisse aus dem vorhergehenden Loop zur Weiterverarbeitung im nächsten Loop
nextLoop=""

while read -r line
do 
  echo "A line of input: $line"
    lvmLvName=$(echo "$line" | awk '{print $1}')
    lvmLvSize=$(echo "$line" | awk '{print $2}')
    fsType=$(echo "$line" | awk '{print $3}')
    fsMountPoint=$(echo "$line" | awk '{print $4}')
    fsTempMountPoint=$(echo "$line" | awk '{print $5}')

    echo "$lvmLvName : $lvmLvSize : $fsType : $fsMountPoint : $fsTempMountPoint"

    # Erstellen des Logical Volumes...
    lvcreate -L $lvmLvSize -n $lvmLvName $lvmVgName

    # Dateisysteme anlegen...
    if [ $fsType == "ext4" ]
    then
        # Dateisysteme auf den LVs anlegen
        mkfs.ext4 /dev/$lvmVgName/$lvmLvName
    elif [ $fsType == "swap" ]
    then
        # Swap Filesystem anlegen
        mkswap /dev/$lvmVgName/$lvmLvName
    else
        # nicht unterstützt - Fehler
        echo "Kein unterstütztes Dateisystem - übersprungen."
    fi

    # Dateisysteme ausgeben, UUID ermitteln
    fsUUID=$(blkid -L | grep -i "\-$lvmLvName:" | grep -o -E '\"[0-9a-z]{8}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{12}\"')
    # Dateisysteme ausgeben, Mapper ermitteln
    fsMapper=$(blkid -L | grep -i "\-$lvmLvName:" | grep -o -E '\/dev\/mapper\/[0-9a-z\-]*')

    
    # ERGEBISSE FÜR NÄCHSTE SCHLEIFE AUFARBEITEN

    # Wenn nextLoop nicht leer ist erstmal einen Zeilenumbruch dranhängen...
    if [ "$nextLoop" != "" ] 
    then
        nextLoop+="\n"
    fi

    # Hier die aufbereiteten Zeilen hin, Spalten jeweils Leerzeichen-separiert
    nextLoop+="$lvmLvName $lvmLvSize $fsType $fsMountPoint $fsTempMountPoint $fsUUID $fsMapper"


done <<<"$lvmLogicalVolumeData"


# NÄCHSTER LOOP - NEUES FS MOUNTEN UND ALTES SYNCEN

# MountPoint für QuellFileSystem
fsOMP="/mnt/src"

# Prüfen ob Mountpoint vorhanden, wenn nicht Verzeichnis anlegen, wenn ja, prüfen ob Verzeichnis leer, wenn nicht, leeren...
if [ ! -d "$fsOMP" ]
then
    mkdir $fsOMP
    # chmod -R u=rwx,g+rw-x,o+rwx $mountpfad
    # Script-Abbruch bei Fehler...
fi 

# Prüfen ob der Mountpoint leer ist
if [ -n "$(ls -A $fsOMP)" ]
then
    # Alles unterhalb des Mountpoint löschen
    find $fsOMP -mindepth 1 -delete
    # Warnung bei Fehler... (kann notfalls im Nachgang händisch entfernt werden)
fi

# Souce mounten
mkdir "$fsOMP"
mount "/dev/sda2" "$fsOMP"

# Jeden einzelnen Mountpoint im LVM mounten, Dateien syncen
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

    # Die weiteren Aktionen nur durchführen, wenn kein swap-FS geliefert wird...
    if [ "$fsType" != "swap" ]
    then
        # Prüfen ob Mountpoint vorhanden, wenn nicht Verzeichnis anlegen, wenn ja, prüfen ob Verzeichnis leer, wenn nicht, leeren...
        if [ ! -d "$fsTempMountPoint" ]
        then
            mkdir $fsTempMountPoint
            # chmod -R u=rwx,g+rw-x,o+rwx $mountpfad
            # Script-Abbruch bei Fehler...
        fi 

        # Prüfen ob der Mountpoint leer ist
        if [ -n "$(ls -A $fsTempMountPoint)" ]
        then
            # Alles unterhalb des Mountpoint löschen
            find $fsTempMountPoint -mindepth 1 -delete
            # Warnung bei Fehler... (kann notfalls im Nachgang händisch entfernt werden)
        fi

        # In Mountpoint mounten
        mount "/dev/$lvmVgName/$lvmLvName" "$fsTempMountPoint"

        fsTgt="$fsMountPoint/" # Nur wenn letztes Zeichen nicht / ist
        # Dateien vom source ins neue Filesystem kopieren
        rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* "$fsOMP$fsTgt*" "$fsTempMountPoint"
    fi

done <<<"$x"


# NÄCHSTER LOOP
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
done <<<"$x"



# FSTAB IM NEUEN ROOT ANPASSEN
# ============================

# alten root-Eintrag ermitteln.
oldRoot=$(grep '^UUID' /etc/fstab | grep '/\s*ext4')

# ersetzen mit # + Zeile alte Partition
sed '/\<UIDalt\>/ c \
Komplette Zeile mit alter UID und vorangestellter #

# neue UID der root part anfügen
sed '/\<UIDalt\>/ a \
Komplette Zeile mit neuer root UID

# neue UID der xxx part anfügen
sed '/\<UIDroot\>/ a \
Komplette Zeile mit neuer xxx UID
'
# ...

# GRUB AKTUALISIEREN
# ==================

# /boot mounten...
mount /dev/sda1 /mnt/root/boot

# Mounten der kritischen virtuellen Dateisysteme
for i in /dev /dev/pts /proc /sys /run; do mount -B $i /mnt/root$i; done

# Chroot into your normal system device:
chroot /mnt/root

# Reinstall GRUB 2 
grub-install /dev/sda

# Recreate the GRUB 2 menu file (grub.cfg)
update-grub

# Exit chroot: CTRL-D on keyboard