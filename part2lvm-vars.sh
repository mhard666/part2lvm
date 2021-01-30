#!/bin/bash

# part2lvm-vars.sh
#
# gemeinsam genutzte Variablen für die part2lvm-Scripte
#
# v. 1.0.0  - 20210128  - mh    - initiale Version
#
# Autor: Mirko Härtwig

### Geräte
devPhysicalVolume="/dev/sda3"                   # Partition auf der das Physical Volume angelegt wird
devSourcePartition="/dev/sda2"                  # Quell-Partition (root-Partition)

### Mountpoints
mpSource="/mnt/src"                             # Mountpoint für Quellsystem
mpDest="/mnt/dst"                               # Mountpoint für die Zielpartition (nur zum syncen der Daten)
mpRoot="/mnt/root"                              # Mountpoint für die root-Partition (nur zum initialen Lesen der fstab)

### LVM
lvmVolumeGroup="vg_debian"                      # Volume Group, die im PV angelegt wird
lvmLogicalVolume="lv_home"                      # Logical Volume, das in der VG angelegt wird (für jeden Durchlauf neu setzen!)
lvmSize="20G"                                   # Größe des Logical Volumes (für jeden Durchlauf neu setzen!)

### Filesystem
fsType="ext4"                                   # Filesystem-Typ z.Zt.: ext4, swap (für jeden Durchlauf neu setzen!)
