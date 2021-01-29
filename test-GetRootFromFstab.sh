#!/bin/bash

# test-GetRootFromFstab.sh
#
# Holt den root-Eintrag aus einer fstab-Datei
#
# v.1.0.0  - 20210129  - mh    - initiale Version
#
# Author: Mirko Härtwig

# ================================================================================================
# part2lvm-utils.sh einbinden...
# ================================================================================================

if [ -f ./part2lvm-utils.sh ] ;then
    . ./part2lvm-utils.sh
else
    echo "ERROR: ./part2lvm-utils.sh not available"
    exit $rERROR_IncludingFail
fi

test=$(getRootFromFstab "fstab")
result=$?
echo "Test: $test"
echo "Result: $result"

read key