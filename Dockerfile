## REF: https://hub.docker.com/r/kalilinux/kali-rolling
FROM docker.io/kalilinux/kali-rolling

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get --quiet update && \
## Install packages
## REF: ./README.md
  apt-get --quiet --yes install --no-install-recommends \
    7zip bmap-tools debos dosfstools e2fsprogs linux-image-amd64 parted qemu-utils systemd-resolved xkb-data xz-utils zerofree && \
## Clean up
  apt-get --quiet --yes --purge autoremove && \
  apt-get --quiet --yes clean
