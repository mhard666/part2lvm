# README

part2lvm ist ein Script, mit dem ein Linux System mit einer boot -und einer root-Partition dahin umgestellt wird, dass die root-Partition hin zu LVM konvertiert wird.

part2lvmKR ist eine abgewandelte Version des Scripts. Auf dem Linux System wird die root-Partition erhalten. Für alle anderen Mountpoints werden Logical Volumes erstellt und die vorhandenen Daten dorthin migriert. Abschließend wird auch hier der Bootloader Grub neu geschrieben.

## Voraussetzungen

Linux Server mit zwei Partitionen, einer Boot-Partition und einer root-Partition, Festplatten im MBR-Modus (GPT nicht getestet), und beide Partitionen auf einem Laufwerk. Das Laufwerk (/dev/sda) enthält den Bootloader, Boot-Partition ist /dev/sda1, Root-Partition ist /dev/sda2.

Gebootet wird von einem Live-System. Mittels gparted ist vor dem Start des Scripts die Root-Partition zu verkleinern, an das Ende des Laufwerks zu schieben und im freigewordenen Speicherbereich eine neue Partition (/dev/sda3) als primäre Partition vom Typ LVM_FS anzulegen. Für part2lvmKR sollte die alte root-Partition ebenfalls verkleinert werden, muss/sollte jedoch nicht ans Ede des Datenträgers verschoben werden, da die neue Partition für LVM PV dauerhaft dahinter angelegt und benannt wird. In dieser Partition werden im Script die Bestandteile des LVMs angelegt.

## Script-Ablauf

. Es wird die Datenstruktur für das neu zu erstellende lvm als mehrzeilige Variable im Script hinterlegt
. Im ersten Schritt legt das Script in der benannten Partition die Bestandteile des LVM an, erst das Physical Volume, dann die Volume Group und anschließend über die mehrzeilige Variable iterierend die Logical Volumes.
. Im nächsten Schritt werden die LVs gemounted und die Daten von den Quellverzeichnissen in die Zielverzeichnisse gesynct
. In Script part2lvmKR werden dann die Dateien in den Quellverzeichnissen gelöscht (dieser Schritt entfällt bei part2lvm, da hier abschließend die gesamte alte Partition gelöscht wird)
. Weiter werden die neuen Mountpoints in die fstab eingetragen
. In part2lvm wird die Quellpartition gelöscht (ToDo)
. Abschließend wird der Bootloader neu geschrieben.

## Sonstiges

/etc/fstab Beispiel:

    # /etc/fstab: static file system information.
    #
    # Use 'blkid' to print the universally unique identifier for a
    # device; this may be used with UUID= as a more robust way to name devices
    # that works even if disks are added and removed. See fstab(5).
    #
    # <file system> <mount point>   <type>  <options>       <dump>  <pass>
    /dev/mapper/debian--vg-root /               ext4    errors=remount-ro 0       1
    # /boot was on /dev/sda2 during installation
    UUID=1ad783e1-ef9a-4355-aa4c-cd6c36379d83 /boot           ext2    defaults        0       2
    # /boot/efi was on /dev/sda1 during installation
    UUID=FCCE-CF27  /boot/efi       vfat    umask=0077      0       1
    /dev/mapper/debian--vg-home /home           ext4    defaults        0       2
    /dev/mapper/debian--vg-tmp /tmp            ext4    defaults        0       2
    /dev/mapper/debian--vg-var /var            ext4    defaults        0       2
    /dev/mapper/debian--vg-swap_1 none            swap    sw              0       0
