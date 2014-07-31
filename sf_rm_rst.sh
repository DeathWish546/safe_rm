#!/bin/bash

#checks if file is in garbage bin, takes as argument $restored File, $1, $restore_info, $#
function existsInGarbage(){
        if [[ $4 -lt 1 ]]; then
                echo -e "safe_rm_restore: missing operand\nTry 'safe_rm_restore --help' for more information."
                exit 1
        fi
        if [ ! -e $1 ]; then
                echo "safe_rm_restore: cannot restore '$2': No such file or directory in recycle bin"
                exit 1
        fi

        checkRestoreInfo=$(grep $2 $3)
        if [ ! $checkRestoreInfo ]; then
                echo "safe_rm_restore: cannot find path of '$2': Does not exist in .restore.info"
                exit 1
        fi
}

#checks if a file with same name already exists, takes as argument $originalFileName, $originalFileDir
function alreadyExists(){
        checkFile=$(ls -a $2| grep ^$1$)
        if [ $checkFile ]; then
                read -p "A file with the same name currently exists in the directory, do you want to overwrite that file with this file? (y/n)" userInput
                if [[ "$userInput" =~ ^[yY] ]]; then
                        echo "The file has been replaced with the one in the recycle bin"
                        rm -r $3
                else
                        echo "The file has not been restored and remains in the recycle bin"
                        exit 0
                fi
        fi
}

#removes the removed file from .restore.info, takes as argument $1 $restore_info
function removeInfo() {
        fileLine=$(cat $2 | grep -n $1 | cut -d":" -f1)
        sed -e "${fileLine}d" $2 > tempfile
        cat tempfile > $2
        rm tempfile
}

#GLOBAL VARIABLES
recycle_bin=$HOME/deleted
restore_info=$HOME/.restore.info
#$1 is the file to be restored

#SCRIPT STARTS

restoredFile=$recycle_bin/$1
existsInGarbage $restoredFile $1 $restore_info $#

#do it this way in case original file had : in name
temp=$(cat $restore_info | grep $1 | cut -d"/" -f2-)
originalFilePath=$(echo /$temp)
#do it this way in case the original file had multple _ in name
originalFileName=$(echo $originalFilePath | rev | cut -d"/" -f1 | rev)
originalFileDir=$(echo $originalFilePath | rev | cut -d"/" -f2- | rev)
alreadyExists $originalFileName $originalFileDir $originalFilePath

mv $restoredFile $originalFilePath

removeInfo $1 $restore_info
