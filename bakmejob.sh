#!/bin/bash

bin=$(eval readlink -m "$0")
bin=$(dirname "$bin")

usage() {
    echo "Usage:"
    echo "    $0 <prjpath> <-r recipient...>"
    echo ""
}
if [ ! "$1" ] || [ ! "$2" ]; then
    usage
    exit 1
fi

cd "$bin"
export LOG=1
./bakme.sh "$1" | ./mailsend.sh "${@:2}"
