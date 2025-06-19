#!/bin/sh

set -eu

zone=$1

if ! [ -e /usr/share/zoneinfo/$zone ]; then
    echo "ERROR: invalid time zone '$zone'"
    exit 1
fi

rm -f /etc/localtime
ln -s /usr/share/zoneinfo/$zone /etc/localtime
