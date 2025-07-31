#!/bin/sh

set -eu

SCRIPTSDIR=$RECIPEDIR/scripts
START_TIME=$(date +%s)

info() { echo "INFO:" "$@"; }

image=
keep=0
vagrant=0
zip=0

while [ $# -gt 0 ]; do
    case $1 in
        -k) keep=1 ;;
        -V) vagrant=1 ;;
        -z) zip=1 ;;
        *) image=$1 ;;
    esac
    shift
done

cd $ARTIFACTDIR

info "Generate $image.vmdk"
qemu-img convert -O vmdk $image.raw $image.vmdk

[ $keep -eq 1 ] || rm -f $image.raw

info "Generate $image.ovf"
$SCRIPTSDIR/generate-ovf.sh $image.vmdk

## Need todo this before generate-mf.sh, otherwise, the checksum will be incorrect
if [ $vagrant -eq 1 ]; then
    info "Applying Vagrant patches"

    ## HACK! We know that user/pass is not kali/kali but vagrant/vagrant
    sed -E -i 's/(Username|Password): kali/\1: vagrant/' $image.ovf

    ## Accept any VM EULA license agreement, otherwise will fail to import
    sed -i '/<EulaSection>/,/<\/EulaSection>/d' $image.ovf
fi

info "Generate $image.mf"
$SCRIPTSDIR/generate-mf.sh $image.ovf $image.vmdk

if [ $zip -eq 1 ]; then
    info "Compress to $image.7z"
    7zr a -sdel -mx=9 $image.7z $image.ovf $image.vmdk $image.mf
fi

for fn in $image.*; do
    [ $(stat -c %Y $fn) -ge $START_TIME ] && echo $fn || :
done > .artifacts
