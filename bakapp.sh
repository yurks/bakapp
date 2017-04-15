#!/bin/bash

export LC_ALL=C
export LANG=C



initTempDir() {
    if [ ! "$tmpdir" ]; then
        local cmd="mktemp -d"
        logeval $cmd
        readonly tmpdir=$($cmd)
        exitIfErr
        log yellow "temp:" "$tmpdir"
    fi
}
removeTempDir() {
    if [ "$tmpdir" ]; then
        local cmd="rm -rf \"$tmpdir\""
        logeval $cmd
        eval "$cmd"
        exitIfErr
        log yellow "temp:" "cleanup"
    fi
}


colors=1
log() {
    echo -n "[$(date -u +%Y%m%d\|%H%M%S)] "
    if [ $colors -eq 1 ]; then
        case "$1" in
            red) echo -en "\033[0;31m"; shift;;
            green) echo -en "\033[0;32m"; shift;;
            yellow) echo -en "\033[0;33m"; shift;;
            blue) echo -en "\033[0;36m"; shift;;
            gray) echo -en "\033[1;30m"; shift;;
        esac
    else
        shift
    fi
    echo -n "$1"
    if [ $colors -eq 1 ]; then
        echo -en "\033[0m"  ## reset color
    fi
    if [ "$2" ]; then
        echo " $2"
    else
        echo
    fi
}

finish() {
    removeTempDir
    if [ "$1" = "ok" ]; then
        log green "exit:" "ok"
        exit 0;
    else
        if [ -n "$1" ]; then
            log red "exit:" "$1"
        else
            log red "exit:" "interrupted"
        fi
        exit 1
    fi

}

exitIfErr() {
    local status=$?
    if [ $1 ]; then
        if [ $status $@ ]; then
            finish "interrupted with code $status"
        fi
    else
        if [ $status -ne 0 ]; then
            finish "interrupted with code $status"
        fi
    fi
    return $status
}

confirmation() {
    local msg="${1:-continue?}"
    read -s -p "$msg (yes/no): " choice
    case "$choice" in
        yes ) echo "yes"; return 0;;
        no ) echo "no"; return 127;;
        * ) echo ""; confirmation "$1";;
    esac
}

logeval() {
    local cmd=("$@")
    log gray "eval: ${cmd[*]}"
}


usage () {
cat <<EOF
Usage:
    $0 <mode> <path> [options...]

Create backup with files in <path>, diff files with last backup

Mode:
    create           create backup
    test             test contents of last created backup
    list             list files to backup
    diff             show differences between last created backup and files actually present in filesystem
    diff-create      create backup ONLY if any diff detected
    restore          restore backup

Path:
    directory for backup or
    database connection string in format db://user:password@host[:port]/database or
    path to backup file for restore mode

Options:
    -e               exclude dir (relative to <path>, multiple options allowed).
    -i               include only specified dir (relative to <path>, multiple options allowed).
    -o               out path for backups (default: current dir)
    -b               base path for <path> (default: current dir)
    -n               backup name (default: generated from <path>)
    -c               compression for backup file acceptable by tar (default: uncompressed)
    -d               compare files by content (diff* modes)
    -x               no colors in output
    -h               unbelievable

EOF
}



basepath="."
outpath="."
compression=""
backupName=""
exclude=()
include=()
diffContent=0

if [ $# -eq 0 ]; then
	usage
	exit 0
fi


args=`getopt -o "e:i:b:o:c:n:xdh" -- "$@"`
exitIfErr

eval set -- "$args"

argslength=$#

while [ $# -ge 1 ]; do
	opt="$1"
    shift
	case "$opt" in
            --) break;;
            -e) exclude+=("$1");;
            -i) include+=("$1");;
            -b) basepath="$1";;
            -o) outpath="$1";;
            -c) compression="$1";;
            -n) backupName="$1";;
            -d) diffContent=1;;
            -x) colors=0;;
            -h) usage;;
    esac
done


mode="$1"; shift
folder="$1"; shift
basepath="$basepath/"
outpath="$outpath/"

log blue "mode:" "$mode"

if [ ! "$folder" ]; then
    log red "path: empty"
    finish
fi




dbargs=()
if [[ ${folder:0:5} == "db://" ]] ; then
    re_db='^db://([^:]+):(.+)@([^/:]+):?([[:digit:]]+)?/([^<]+)<?(.*)$'
    if [[ "$folder" =~ $re_db ]]; then
        dbargs+=("--host=${BASH_REMATCH[3]}")
        if [ "${BASH_REMATCH[4]}" ]; then
            dbargs+=("--port=${BASH_REMATCH[4]}")
        fi
        dbargs+=("--password=\"${BASH_REMATCH[2]}\"")
        dbargs+=("--user=${BASH_REMATCH[1]}")

        folder="${BASH_REMATCH[5]}"
        log yellow "db:" "${BASH_REMATCH[5]}"
        dbargs+=("${BASH_REMATCH[5]}")

        if [ "$mode" = "restore" ]; then
            if [ ! "${BASH_REMATCH[6]}" ] || [ ! -f "${BASH_REMATCH[6]}" ]; then
                log red "file: invalid backup file" "${BASH_REMATCH[6]}"
                finish
            fi
            log yellow "file:" "${BASH_REMATCH[6]}"
            dbargs+=("< \"${BASH_REMATCH[6]}\"")
        fi
    else
        log red "db: invalid connection string"
        finish
    fi

else

    if [ "$mode" = "restore" ]; then
        if [ ! "$outpath" ]; then
            outpath="$basepath"
        fi
        if [ ! -d "$outpath" ]; then
            log red "path: invalid:" "$outpath"
            finish
        fi
        log yellow "path:" "$outpath"


        if [ ! -f "$folder" ]; then
            log red "file: invalid:" "$folder"
            finish
        fi
        log yellow "file:" "$folder"

        confirmation "restore backup?"
        exitIfErr

        cmd="tar -xapsf \"$folder\" --directory \"$outpath\" --totals"
        logeval $cmd
        eval "$cmd"
        exitIfErr
        finish "ok"
    fi

    if [ ! -d "$basepath$folder" ]; then
        log red "path: invalid:" "$basepath$folder"
        finish
    fi
    log yellow "path:" "$basepath$folder"
fi

if [ ! "$backupName" ]; then
    backupName="$folder"
fi

re='(.*)[\/\.]+(.*)'
while [[ "$backupName" =~ $re ]]; do
   backupName=${BASH_REMATCH[1]}-${BASH_REMATCH[2]}
done

backupTime=$(date -u +%Y%m%d-%H%M%S)
timeSepatator="."

backupFile="$backupName$timeSepatator$backupTime"

if [ ${#dbargs[*]} -gt 0 ]; then

    hidePassword() {
        echo "${1/--password=\"*\" --user=/--password --user=}"
    }

    if [ "$mode" = "restore" ]; then
        confirmation "restore database?"
        exitIfErr

        cmd="mysql ${dbargs[@]}"
        logeval $(hidePassword "$cmd")
        eval "$cmd"
        exitIfErr
        finish "ok"
    fi

    if [ "$mode" != "create" ] && [ "$mode" != "diff-create" ]; then
        finish "invalid mode"
    fi

    backupSql="$backupFile.sql"

    cmd="mysqldump --opt --skip-dump-date --no-data --no-create-info ${dbargs[@]} > /dev/null"
    logeval $(hidePassword "$cmd")
    eval "$cmd"
    exitIfErr

    cmd="mysqldump --opt --skip-dump-date --single-transaction --no-data ${dbargs[@]} > \"$outpath$backupSql\""
    logeval $(hidePassword "$cmd")
    eval "$cmd"
    exitIfErr

    excluding=""
    for i in "${!exclude[@]}"; do
       excluding="$excluding --ignore-table=$folder.${exclude[$i]}"
    done

    cmd="mysqldump --opt --skip-dump-date --no-create-info ${dbargs[@]} $excluding >> \"$outpath$backupSql\""
    logeval $(hidePassword "$cmd")
    eval "$cmd"
    exitIfErr

    if [ "$compression" ] ; then
        cmd="$compression \"$outpath$backupSql\""
        logeval "$cmd"
        eval "$cmd"
        exitIfErr
    fi

    finish "ok"

fi

backupFile+=".tar"
if [ "$compression" ] ; then
    backupFile+=".$compression"
fi


if [ "$mode" = "test" ] || [[ $mode == diff* ]] ; then
    cmd="find \"$outpath\" -regex \"$outpath$backupName\\$timeSepatator.*\" | sort -r | head -1"
    log gray "eval: $cmd"
    existBackup=$(eval "$cmd")
    exitIfErr

    if [ ! "$existBackup" ] || [ ! -f "$existBackup" ]; then
        if [ "$mode" = "diff-create" ]; then
            mode="create"
            log yellow "file:" "error with last backup"
            log blue "mode:" "$mode"
        else
            finish "invalid file $existBackup"
        fi
    else
        log yellow "file:" "$existBackup"
        cmd="tar -tapsf \"$existBackup\""
        cmdTest="$cmd"

        if [ "$mode" = "diff-create" ]; then
            logeval $cmd
            eval "$cmd" > /dev/null
            if [ $? -gt 1 ]; then
                mode="create"
                log yellow "file:" "error with last backup"
                log blue "mode:" "$mode"
            fi
        fi
    fi
fi


if [ "$mode" = "list" ] || [[ $mode == diff* ]] ; then
    excluding=""
    for i in "${!exclude[@]}"; do
       excluding="$excluding -not -regex \"$folder/${exclude[$i]}$\" -not -regex \"$folder/${exclude[$i]}/.*\""
    done
    including=""
    for i in "${!include[@]}"; do
        if [ "$including" ]; then
            including="$including -or"
        fi
           including="$including -regex \"$folder/${include[$i]}$\" -or -regex \"$folder/${include[$i]}/.*\""
    done
    if [ "$excluding" ] && [ "$including" ]; then
        excluding="$excluding -and"
    fi
    if [ "$including" ]; then
        including="\($including \)"
    fi
    cmd="(cd \"$basepath\"; find \"$folder\" $excluding $including \( -type d -printf \"%p/\n\" , -type f -print \))"
    cmdList=$cmd
fi


hasdiff=0
if [[ $mode == diff* ]]; then

    cmd="diff -U 0 <($cmdTest | sort) <($cmdList | sort)"
    logeval $cmd
    diffFiles=$(eval "$cmd")
    exitIfErr -gt 1
    if [ $? -eq 0 ]; then
        log yellow "diff:" "eqals"
    else
        hasdiff=1
        log yellow "diff:"
        echo "$diffFiles" | grep "^[^@]" | sed 1,2d
    fi

    cmd="tar -dapsf \"$existBackup\" --directory \"$basepath\""
    logeval $cmd
    diffFiles=$(eval "$cmd")
    exitIfErr -gt 1

    if [ $? -eq 0 ]; then
        log yellow "diff:" "eqals"
    else
        if [ "$diffFiles" ]; then
            hasdiff=1

            if [ $diffContent -eq 1 ]; then

                re='^(.+): (.+)$'
                somethingDiffer=$(echo "$diffFiles" | while read -r f ; do
                    if [[ "$f" =~ $re ]]; then
                        echo "${BASH_REMATCH[1]}"
                    fi
                done | uniq)

                if [ "$somethingDiffer" ]; then
                    initTempDir

                    cmd="tar -xapsf \"$existBackup\" --directory \"$tmpdir\""
                    logeval "$cmd -T <( echo \"\$somethingDiffer\" )"
                    eval "$cmd -T <( echo \"$somethingDiffer\" )"

                    log yellow "diff:"

                    echo "$diffFiles" | while read -r f ; do
                        if [[ "$f" =~ $re ]]; then
                            echo "~$f"
                            if [ "${BASH_REMATCH[2]}" = "Contents differ" ] || [ "${BASH_REMATCH[2]}" = "Size differs" ]; then
                                cmd="diff -us \"$tmpdir/${BASH_REMATCH[1]}\" \"$basepath${BASH_REMATCH[1]}\" --label \"\$(ls -l --full-time \"$tmpdir/${BASH_REMATCH[1]}\")\" --label \"\$(ls -l --full-time \"$basepath${BASH_REMATCH[1]}\")\""
                                logeval $cmd
                                eval "$cmd"
                            fi
                        fi
                    done

                fi
            else
                echo "$diffFiles" | while read -r f; do echo "~$f"; done
            fi

        fi
    fi

    if [ "$mode" = "diff-create" ]; then
        if [ $hasdiff -eq 0 ]; then
            finish "ok"
        else
            mode="create"
            log blue "mode:" "$mode"

        fi
    else
        finish "ok"
    fi
fi


if [ "$mode" = "create" ]; then
    log yellow "file:" "$outpath$backupFile"
    excluding=""
    for i in "${!exclude[@]}"; do
        #TODO: exclude by regexp, not by pattern
        excluding="$excluding --exclude=\"$folder/${exclude[$i]}\""
    done
    cmd="tar $excluding -capf \"$outpath$backupFile\" --directory \"$basepath\" --totals"

    if [ ${#include[@]} -ne 0 ]; then
        for i in "${!include[@]}"; do
            cmd+=" \"$folder/${include[$i]}\""
        done
    else
        cmd+=" \"$folder\""
    fi
fi


if [ ! "$cmd" ]; then
    finish "invalid mode"
fi

logeval $cmd
eval "$cmd"
exitIfErr
finish "ok"
