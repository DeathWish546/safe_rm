#!/bin/bash
#GLOBAL VARIABLES
RECYCLE_BIN=$HOME/deleted
RESTORE_INFO=$HOME/.restore.info

##############################################################################################
#ALL FUNCTIONS

#checks if it's a file or directory, given $1
function fileOrDir() {
        if [ -d $1 ]; then
                echo "directory"
        else
                echo "file"
        fi
}


#checks $# and $1 for arguments, takes as argument $1
function checkArgumentOne(){
        if [ $# -lt 1 ]; then
                echo -e "safe_rm: missing operand\nTry 'safe_rm --help' for more information."
                exit 1
        fi

        if [ ! -e $1 ]; then
                echo "safe_rm: cannot remove '$1': No such file or directory"
                exit 1
        fi
}

#change filename to filename_inode, takes as argument $name, $filedir
function changeName() {
        ls -il $2| tr -s " " | cut -d" " -f10 > tempfile
#       cat tempfile
        numLines=$(wc -l tempfile | cut -d" " -f1)
#       echo $numLines
        ls -il $2| tr -s " " | cut -d" " -f1 >> tempfile
#       cat tempfile
        fileLine=$(cat tempfile | grep -n ^$1$ | cut -d":" -f1)
#       echo $fileLine
        inodeLine=$(($fileLine + $numLines))
#       echo $inodeLine
        inode=$(sed -n ${inodeLine}p tempfile)
#       echo $inode
        rm tempfile
        echo $1'_'$inode
}

#append new file to restore_info, takes as argument $newFileName, $restore_info, $file_link
function restoreAppend() {
        if [ ! -e $2 ]; then
                echo "$1:$3" > $2
        else
                echo "$1:$3" >> $2
        fi
}

#remove all files/subdirectories in a directory, takes as argument $i(dir name), $opti, $optv, $optr
function removeRecursively() {
        #remove files first, then directories
        find $1 | tr " " "\n" > tempfile
        touch curdir
        while [ -s tempfile ]
        do
                i=$(head -1 tempfile)
                file_link=$(readlink -f $i)
                test=$(fileOrDir $i)

                thisDir=$(tail -1 curdir)
                thisDirNotEmpty=$(ls -A $thisDir)

                if [ $thisDir ]; then
                        if ! [ $thisDirNotEmpty ]; then
                                optionI $2 $thisDir
                                removeAndUpdate $thisDir $file_link
                                optionV $3 $test $thisDir

                                sed -e '$d' curdir > tempcurdir
                                cat tempcurdir > curdir
                                rm tempcurdir
                                continue
                        fi
                fi

                if [[ "$test" == "directory" && $2 -eq 0 ]]; then
                        read -p "safe_rm: descend into directory '$i'?" input
                        if [[ "input" =~ ^[yY] ]]; then
                                head -1 tempfile >> curdir
                                sed -e '1d' tempfile > temptemp
                                cat temptemp > tempfile
                                rm temptemp
                        else
                                grep -v $i tempfile> temptemp
                                cat temptemp > tempfile
                                rm temptemp
                        fi
                        optionI $2 $i
                        removeAndUpdate $i $file_link
                        optionV $3 $test $i
                        continue
                fi

#               optionI $2 $i
#               removeAndUpdate $i $file_link
#               optionV $3 $test $i

#               sed -e '1d' tempfile> temptemp
#               cat temptemp > tempfile
#              rm temptemp

        done
        rm tempfile
        rm curdir
        
#               if [ $optr -eq 1 ]; then
#                       echo "safe_rm: cannot remove '$i': is a directory"
#               elif [ $optr -eq 0 ]; then
#                        removeRecursively $i $opti $optv $optr
#               fi

}

#removes file and updates restore.info, takes as argument $i, $file_link
function removeAndUpdate() {
        filedir=$(echo $2 | rev | cut -d"/" -f2- | rev)
        filename=$(echo $1 | rev | cut -d"/" -f1 | rev)

        newFileName=$(changeName $filename $filedir)
        mv $1 $RECYCLE_BIN/$newFileName
        restoreAppend $newFileName $RESTORE_INFO $2
}

#option i, takes as argument $opti, $i
function optionI() {
        if [ $1 -eq 0 ]; then
                printf "safe_"
                rm -i $2 <<< n
                read input
                if ! [[ "$input" =~ ^[yY] ]]; then
                        continue
                fi
        fi
}

#option v, takes as argument $optv, $test, $i
function optionV() {
        if [ $1 -eq 0 ]; then
                if [[ "$2" == "directory" ]]; then
                        echo "removed directory: '$3'"
                else
                        echo "removed '$3'"
                fi
        fi
}

##############################################################################################
#INITIALIZING OPTINO VARIABLES
opti=1
optv=1
optr=1

#GETOPTS
while getopts :ivr opts
do
        case $opts in
                i) opti=0 ;;
                v) optv=0 ;;
                r) optr=0 ;;
                R) optr=0 ;;
                ?) echo -e "safe_rm: invalid option -- '$?'\nTry 'safe_rm --help for more information."
                exit 1;;
        esac
done
shift $((OPTIND-1))

#SCRIPT START
if [ ! -d $RECYCLE_BIN ]; then
        mkdir $RECYCLE_BIN
fi

checkArgumentOne $1

for i in $*
do
        file_link=$(readlink -f $i)
        test=$(fileOrDir $i)
        #echo "\$file_link is $file_link"
        echo $opti $optv $optr
        if [[ "$test" == "directory" ]]; then
                if [ $optr -eq 1 ]; then
                        echo "safe_rm: cannot remove '$i': Is a directory"
                elif [ $optr -eq 0 ]; then
                        removeRecursively $i $opti $optv $optr
                fi
                continue
        fi

        optionI $opti $i

#       if [ $opti -eq 0 ]; then
#               printf "safe_"
#               rm -i $i <<< n
#               read input
#               if ! [[ "$input" =~ ^[yY] ]]; then
#                       continue
#               fi
#       fi

        removeAndUpdate $i $file_link #$recycle_bin $restore_info

#       filedir=$(echo $file_link | rev | cut -d"/" -f2- | rev)
#       filename=$(echo $i | rev | cut -d"/" -f1 | rev)
#       #echo "\$filename is $filename"
#       #echo "\$filedir is $filedir"
#
#       newFileName=$(changeName $filename $filedir)
#       #echo "\$newFileName is $newFileName"
#       mv $i $recycle_bin/$newFileName
#       restoreAppend $newFileName $restore_info $file_link
        optionV $optv $test $i
#       if [ $optv -eq 0 ]; then
#               echo "removed '$i'"
#       fi
done
