#!/bin/sh

set -eu

swaptype=$1
swapsize=$2
swapdev=
swapfile=

case $swaptype in
    file)
        swapfile=/swap
        ;;
    partition)
        # assume swap is the last partition
        swapdev=$(lsblk --raw -no path $IMAGE | tail -n 1)
        ;;
    none)
        ;;
    *)
        echo "ERROR: Unsupported swap type '$swaptype'"
        exit 1
        ;;
esac

if [ "$swapdev" ]; then
    echo "INFO: Setting up swap partition $swapdev"

    mkswap -L swap $swapdev
    uuid=$(swaplabel $swapdev | sed -n 's/^UUID: *//p')
    if [ ${#uuid} != 36 ]; then
        echo "ERROR: failed to get swap UUID"
        exit 1
    fi
    echo "UUID=$uuid none swap defaults 0 0" >> /etc/fstab
    echo "RESUME=UUID=$uuid" > /etc/initramfs-tools/conf.d/resume
    # the initrd will be rebuilt later, no need to do it now

elif [ "$swapfile" ]; then
    echo "INFO: Setting up swap file $swapfile"

    fallocate -v -l $swapsize $swapfile
    chmod 600 $swapfile
    mkswap $swapfile
    echo "$swapfile none swap defaults 0 0" >> /etc/fstab

    # I don't think there's a way to resume from a swap file,
    # despite what people say about using resume_offset...
fi
