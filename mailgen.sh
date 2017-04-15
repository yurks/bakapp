#!/bin/bash

bin=$(eval readlink -m "$0")
bin=$(dirname "$bin")
bin="$bin/lib/mailgen.php"

if [ ! "$_ACTUAL_BIN" ]; then
    export _ACTUAL_BIN="$0"
fi
php "$bin" "$@"