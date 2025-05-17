#!/bin/sh

set -eu

SCRIPTSDIR=$RECIPEDIR/scripts
START_TIME=$(date +%s)

info() { echo "INFO:" "$@"; }

image=
keep=0
keyboard=
zip=0

while [ $# -gt 0 ]; do
    case $1 in
        -k) keep=1 ;;
        -K) shift  # Move to the next argument to get the value for keyboard
            if [ $# -gt 0 ]; then
                keyboard=$1
            fi
            ;;
        -z) zip=1 ;;
        *) image=$1 ;;
    esac
    shift
done

cd $ARTIFACTDIR

info "Generate $image.vdi"
qemu-img convert -O vdi $image.raw $image.vdi
[ $keep -eq 1 ] || rm -f $image.raw

info "Generate $image.vbox"
$SCRIPTSDIR/generate-vbox.sh -K $keyboard $image.vdi

if [ $zip -eq 1 ]; then
    info "Compress to $image.7z"
    mkdir $image
    mv $image.vdi $image.vbox $image
    7zr a -sdel -mx=9 $image.7z $image
fi

for fn in $image.*; do
    [ $(stat -c %Y $fn) -ge $START_TIME ] && echo $fn || :
done > .artifacts
