#!/bin/bash
#IFS=$'\n' 

var='lv_root 10G ext4 /mnt/new
lv_swap 16G swap
lv_home 20G ext4
lv_opt 2G ext4
lv_var 5G ext4
lv_var_log 5G ext4
lv_var_tmp 5G ext4
lv_var_lib_postgresql 40G ext4'

# var=$(echo -e 'bla1 bla2 bla3
#bli1 bli2 bli3
#blubb1 blubb2 blubb3')
# echo "$var"

while read -r line
do 
  echo "A line of input: $line"
    name=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    type=$(echo "$line" | awk '{print $3}')
    mp=$(echo "$line" | awk '{print $4}')
    echo "$name --- $size --- $type --- $mp"
    x=$(echo $mp)
    if [ "$x" != "" ]
    then 
        echo $x 
    else
        echo xxxxxxxxx
    fi
done <<<"$var"

