#!/bin/sh

set -eu

layout=$1

valid_layouts=$(cat /usr/share/X11/xkb/rules/xorg.lst | sed -n '/^! layout/,/^$/p' | awk 'NR > 1 {print $1}')

if ! $(echo "$layout" | grep -q "$layout"); then
    echo "ERROR: invalid keyboard layout '$layout'"
    exit 1
fi

if ! [ -e /etc/default/keyboard ]; then
    echo "ERROR: keyboard layout could not be set and defaults to us!"
else
    sed -i -E "s/XKBLAYOUT=\".*\"/XKBLAYOUT=\"$layout\"/" /etc/default/keyboard
fi
