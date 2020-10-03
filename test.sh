#!/bin/bash
#IFS=$'\n' 

function test {
    echo "--"
    return 1
}

function stripEmptyVars {
    # Parameter prüfen
    if [ $# -lt 2 ]
    then
        #log "regular" "WARNING" "function fillEmptyVars() - Fehler Parameterübergabe"
        # echo "usage: $0 INSTRING FILLER"
        return 2    # Returncode 2 = Fehler, Übergabeparameter
    fi

    # Übergabeparameter abholen
    sEVInString=$1
    sEVFiller=$2

    # echo $1
    if [ "$sEVInString" == "$sEVFiller" ]; then
        # Input-String ist gleich Füllstring - leeren String setzen
        echo ""
        return 0
    else
        # Input-String ungleich Füllstring - Input string zurückgeben
        echo $sEVInString
        return 1
    fi
}

function fillEmptyVars {
    # Parameter prüfen
    if [ $# -lt 2 ]
    then
        # echo "usage: $0 INSTRING FILLER"
        return 2    # Returncode 2 = Fehler, Übergabeparameter
    fi

    # Übergabeparameter abholen
    fEVInString=$1
    fEVFiller=$2

    # echo "InString: $1"
    if [ "$fEVInString" == "" ]; then
        # Input-String ist leer - mit Füllstring füllen
        echo $fEVFiller
        return 0
    else
        # Input-String ist nicht leer - Input string zurückgeben
        echo $fEVInString
        return 0
    fi
}


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

newVar=""

while read -r line
do 
  echo "A line of input: $line"
    name=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    type=$(echo "$line" | awk '{print $3}')
    mp=$(echo "$line" | awk '{print $4}')
    echo "$name --- $size --- $type --- $mp"

    # Wenn newVar nicht leer ist erstmal einen Zeilenumbruch dranhängen...
    if [ "$newVar" != "" ] 
    then
        newVar+="\n"
    fi

    newVar+="$name :: $size :: $style"

    x=$(echo $mp)
    if [ "$x" != "" ]
    then 
        echo $x 
    else
        echo xxxxxxxxx
    fi
done <<<"$var"

x=$(echo -e "$newVar")
while read -r line 
do
    echo " ---> $line"
done <<<"$x"

test "x"
r=$?
if [ $r -eq 0 ]; then
    echo "true"
elif [ $r -eq 1 ]; then
    echo "1"
else
    echo "false"
fi

f="none"

s="bla"
fillEmptyVars "$s" "$f"
echo $?

s="hallo"
s=$(fillEmptyVars "$s" "$f")
echo $?
echo "01: String ist -$s-"

s=""
s=$(fillEmptyVars "$s" "$f")
echo $?
echo "02: String ist -$s-"

s=$(stripEmptyVars "$s" "$f")
echo $?
echo "03: String ist -$s-"

