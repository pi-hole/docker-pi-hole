#!/bin/bash

# Prefix each line from STDIN with the current date/time/timezone and write to PID 1 STDOUT (docker log)
while IFS= read -r line; do
    printf '%s %s\n' "$(date '+%F %T.%3N %Z')" "$line" >>/proc/1/fd/1
done
