#!/bin/bash

# part2lvm.sh
# v. 0.0.1     - initiale Version


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
lvmLogicalVolumeData='lv_root 10G ext4
lv_swap 16G swap
lv_home 20G ext4
lv_opt 2G ext4
lv_var 5G ext4
lv_var_log 5G ext4
lv_var_tmp 5G ext4
lv_var_lib_postgresql 40G ext4'

while read -r line
do 
  echo "A line of input: $line"
    lvmLvName=$(echo "$line" | awk '{print $1}')
    lvmLvSize=$(echo "$line" | awk '{print $2}')
    fsType=$(echo "$line" | awk '{print $3}')
    echo "$lvmLvName : $lvmLvSize : $fsType"

    lvcreate -L $lvmLvSize -n $lvmLvName $lvmVgName

    if ($fsType = "ext4")
    then
        # Dateisysteme auf den LVs anlegen
        mkfs.ext4 /dev/$lvmVgName/$lvmLvName
    elif ($fsType = "swap")
    then
        # Swap Filesystem anlegen
        mkswap /dev/$lvmVgName/$lvmLvName
    else
        # nicht unterstützt - Fehler
        echo "Kein unterstütztes Dateisystem - übersprungen."

done <<<"$lvmLogicalVolumeData"


# neues und altes root-Dateisystem mounten
mkdir /mnt/root
mkdir /mnt/old
mount /dev/vg_/lv_root /mnt/root
mount /dev/sda2 /mnt/old

# Dateien vom alten root ins neue kopieren
rsync -aAXv --exclude=/lost+found --exclude=/root/trash/* --exclude=/var/tmp/* /mnt/old/* /mnt/root/


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