#!/bin/bash

bin=$(eval readlink -m "$0")
bin=$(dirname "$bin")
bin="$bin/mailgen.sh"

export _ACTUAL_BIN="$0"
out=$("$bin" "$@")
if [ $? -ne 0 ]; then
    echo "$out"
    exit 1
fi

echo "$out" | sed 1,4d | /usr/sbin/sendmail -t
