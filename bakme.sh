#!/bin/bash

appname="bakme"
bin=$(eval readlink -m "$0")
bin=$(dirname "$bin")
bin="$bin/bakapp.sh"
#echo "$bin"

usage() {
	echo "Usage:"
	echo "    $0 <prjpath> <app|content|db> restore <backupfile> [outpath]"
	echo "    $0 <prjpath> [all]|<app|content|db> [diff-create]|<create|diff|test|list>"
	echo ""
}

if [ ! "$1" ]; then
	usage
	exit 1
fi

parsePrjPath() {

	if [ ! "$2" ]; then
		return 1
	fi

	local prjpath=$(eval readlink -m "$2")
	if [ ! -d "$prjpath" ]; then
		return 1
	fi

	local prj=$(basename "$prjpath")

	if [ ! "$prj" ]; then
		return 1
	fi

	local config="$prjpath/.$appname"
	if [ ! -f "$config" ]; then
		unset
	fi
	local base=$(dirname "$prjpath")

	if [ ! "$base" ] || [ "$base" == "$prjpath" ]; then
		return 1
	fi
	readarray -t "$1" < <(echo "$prjpath"; echo "$prj"; echo "$base"; if [ -f "$config" ]; then echo "$config"; fi)
	return 0
}


parseOutDir() {
	local value="$2"
	local subdir="$3"
	local prjpath="$1"
	if [ "${value:0:1}" != "~" ] && [ "${value:0:1}" != "/" ]; then
        if [ ${value:0:1} != "." ]; then
		    value="./$value"
	    fi
		value="$prjpath/$value"
	fi

    if [ "$subdir" ]; then
        if [ "${value: -1}" != "/" ]; then
	        value+="/"
        fi
	    value="$value$subdir"
    fi

	value=$(eval readlink -m "$value")
	if [ ! -d "$value" ]; then
		mkdir -p "$value"
	fi
	if [ ! -d "$value" ]; then
   		echo "$value"
		return 1
	fi
    echo "$value"
	return 0
}


parsePrjPath "parsedPrj" "$1"
if [ $? -ne 0 ]; then
	echo "invalid project path: $1"
	exit 1
fi
prjpath="${parsedPrj[0]}"
prj="${parsedPrj[1]}"
base="${parsedPrj[2]}"
configPath="${parsedPrj[3]}"


logfile=""
if [ "$LOG" = "1" ]; then
	if [ "$mode" != "restore" ]; then
		logfile="$appname.$(date -u +%Y%m%d).log"
	fi
	unset LOG
fi

out=""
initOutStore() {
	if [ ! "$out" ]; then
		out=$(parseOutDir "$1" "$2" "$3")
		if [ $? -ne 0 ]; then
	        echo "Can not use as outpath: $out"
	        exit 1
        fi

	fi
}


run() {
    local redir="/dev/stdout"
	local color=""
	if [ "$logfile" ]; then
	    redir="$out/$logfile"
	    color="-x"
	fi
	echo "" >> "$redir"
	echo "$(date -u -R)" >> "$redir"

    if [ $# -eq 0 ]; then
	    echo "nothing to do." >> "$redir"
	else
        $bin "$@" $color &>> "$redir"
    fi

}


mode="diff-create"
what="all"

if [ "$2" ]; then
	what="$2"
fi

if [ "$3" ]; then
	mode="$3"
fi

existbackup=""
if [ "$4" ]; then
	existbackup=$(eval readlink -m "$4")
fi

if [ "$mode" = "restore" ]; then
	if [ "$5" ]; then
	    initOutStore "." "$5"
	else
	    initOutStore "$prjpath" "$base"
	fi
fi


re="^[[:blank:]]*([^[:blank:]]*)[[:blank:]]*=[[:blank:]]*(.*)[[:blank:]]*$"
re2="^(\./)?([^[:blank:]]*)?[[:blank:]]*(.*)$"

executed=0
operate() {
	initOutStore "$prjpath" "$base"

	executed=1
	local key="$2"
	local value="$1"

	if [[ "$value" =~ $re2 ]]; then
	    local path="${BASH_REMATCH[2]}"
		local opts="${BASH_REMATCH[3]}"

		if [ "$key" == "db" ] ; then
			if [ "$mode" = "restore" ]; then
	    		path+="<$existbackup"
	    	fi
			run $mode "db://$path" -b "$base" -o "$out" -n "${prjName:-$prj}-$key" $opts
		else
			if [ "$mode" = "restore" ]; then
	    	    path="$existbackup"
	    	else
	    		if [ "$path" ]; then
	    		   path="/$path"
	    	    fi
	        	path="$prj$path"

	        fi

            if [ "$key" ]; then
                key="-$key"
            fi


	    	run $mode "$path" -b "$base" -o "$out" -n "${prjName:-$prj}$key" $opts
		fi
	fi
}


if [ "$configPath" ]; then
    readarray -t config < "$configPath"
else
    operate
    exit
fi

for i in "${!config[@]}"; do
    line="${config[$i]}"
	if [[ -n $line ]]; then
	    key=""
	    value=""
	    if [[ "$line" =~ $re ]]; then
	    	key="${BASH_REMATCH[1]}"
	    	value="${BASH_REMATCH[2]}"

            if [ "${key:0:1}" != "#" ]; then
                if [ "$key" == "out" ]; then
                    initOutStore "$prjpath" "$value" "${prjName:-$prj}"
                elif [ "$key" == "name" ]; then
                    prjName="$value"
                else
                    if [ "$what" == "all" ] && [ "$mode" != "restore" ]; then
                        operate "$value" "$key"
                    elif [ "$what" == "$key" ]; then
                        operate "$value" "$key"
                    fi
                fi
            fi

        fi
	fi
done

if [ $executed -eq 0 ]; then
	run
fi

if [ "$logfile" ] && [ -f "$out/$logfile" ]; then
    echo "@@MAILGEN:attachment@@$out/$logfile"
    cat "$out/$logfile"
fi
