#!/bin/sh

set -eu

SCRIPTSDIR="$RECIPEDIR/scripts"
WORKSPACEDIR="$ARTIFACTDIR/workspace"

info() { echo "INFO:" "$@"; }
fail() { echo "$@" >&2; exit 1; }

image=
variant=
keep=0
zip=0

while [ $# -gt 0 ]; do
    case $1 in
        -k) keep=1 ;;
        -z) zip=1 ;;
        *) image=$1; shift; variant=$1 ;;
    esac
    shift
done

vagrantfile_hyperv='
  ## REF: https://developer.hashicorp.com/vagrant/docs/providers/hyperv/configuration
  config.vm.provider :hyperv do |hyperv|
    hyperv.enable_virtualization_extensions = true
  end
'

vagrantfile_libvirt='
  ## $ virsh --connect qemu:///system list --all
  ## $ virsh --connect qemu:///session list --all

  ## REF: https://vagrant-libvirt.github.io/vagrant-libvirt/
  config.vagrant.plugins = "vagrant-libvirt"

  ## REF: https://vagrant-libvirt.github.io/vagrant-libvirt/boxes.html
  config.vm.provider :libvirt do |libvirt|
    libvirt.disk_bus = "virtio"
    libvirt.driver = "kvm"
    libvirt.video_vram = 256

    ## qemu:///session == user session   (Think non-root - current user)
    ## qemu:///system  == system session (Think root - access to full system resources)
    #libvirt.uri = 'qemu:///session'

    #config.vm.synced_folder ".", "/vagrant", type: "9p"
  end
'

vagrantfile_virtualbox='
  ## $ VBoxManage list vms

  ## REF: https://developer.hashicorp.com/vagrant/docs/providers/virtualbox/configuration
  config.vm.provider :virtualbox do |vb, override|
    vb.gui = false
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
  end
'

vagrantfile_vmware_desktop='
  ## $ vmrun list

  ## REF: https://developer.hashicorp.com/vagrant/install/vmware
  config.vagrant.plugins = "vagrant-vmware-desktop"

  ## REF: https://developer.hashicorp.com/vagrant/docs/providers/vmware/configuration
  config.vm.provider :vmware_desktop do |vmware|
    vmware.gui = false
    vmware.vmx["ide0:0.clientdevice"] = "FALSE"
    vmware.vmx["ide0:0.devicetype"] = "cdrom-raw"
    vmware.vmx["ide0:0.filename"] = "auto detect"
  end
'

metadata=
provider=
vagrantfile=

cd "${RECIPEDIR}/"
rm -rf "$WORKSPACEDIR"
mkdir "$WORKSPACEDIR/"

case $variant in
    hyperv)
        provider=hyperv
        vagrantfile=$vagrantfile_hyperv
        info "Generate $image.vhdx"
        qemu-img convert -O vhdx "$ARTIFACTDIR/$image.raw" "$ARTIFACTDIR/$image.vhdx"
        info "Generate box.xml"
        "$SCRIPTSDIR/generate-xml.sh" "$ARTIFACTDIR/$image.vhdx"
        mkdir "$WORKSPACEDIR/Virtual Hard Disks/"
        mkdir "$WORKSPACEDIR/Virtual Machines/"
        mv "$ARTIFACTDIR/$image.vhdx" "$WORKSPACEDIR/Virtual Hard Disks/"
        mv "$ARTIFACTDIR/$image.xml"  "$WORKSPACEDIR/Virtual Machines/box.xml"
        ;;
    qemu)
        provider=libvirt
        vagrantfile=$vagrantfile_libvirt
        info "Generate $image.qcow2"
        qemu-img convert -O qcow2 "$ARTIFACTDIR/$image.raw" "$ARTIFACTDIR/$image.qcow2"
        mv "$ARTIFACTDIR/$image.qcow2" "$WORKSPACEDIR/"
        metadata='"disks": [{"format": "qcow2", "path": "'$image'.qcow2"}],'
        ;;
    virtualbox)
        provider=virtualbox
        vagrantfile=$vagrantfile_virtualbox
        info "Generate $image.vmdk, $image.ovf and $image.mf"
        "$SCRIPTSDIR/export-ovf.sh" "$ARTIFACTDIR/$image"
        mv "$ARTIFACTDIR/$image.vmdk" "$ARTIFACTDIR/$image.ovf" "$ARTIFACTDIR/$image.mf" \
            "$WORKSPACEDIR/"
        ;;
    vmware)
        provider=vmware_desktop
        vagrantfile=$vagrantfile_vmware_desktop
        info "Generate $image.vmdk"
        qemu-img convert -O vmdk -o subformat=twoGbMaxExtentSparse \
            "$ARTIFACTDIR/$image.raw" "$WORKSPACEDIR/$image.vmdk"
        info "Generate $image.vmx"
        "$SCRIPTSDIR/generate-vmx.sh" "$WORKSPACEDIR/$image.vmdk"
        ;;
    *)
        fail "ERROR: Unsupported variant '$variant'"
        ;;
esac

[ $keep -eq 1 ] || rm -f "$ARTIFACTDIR/$image.raw"

info "Vagrant provider: $provider"

## $ vagrant box list -i
info "Generate info.json"
cat << EOF | python3 -m json.tool > "$WORKSPACEDIR/info.json"
{
  "author": "Kali Linux",
  "homepage": "https://www.kali.org/",
  "build-script": "https://gitlab.com/kalilinux/build-scripts/kali-vm",
  "vagrant-cloud": "https://portal.cloud.hashicorp.com/vagrant/discover/kalilinux"
}
EOF

## TODO:
##   - May be nice to import other metadata, such as: `-a ARCH`, `-b BRANCH` & `-x VERSION`
info "Generate metadata.json"
cat << EOF | python3 -m json.tool > "$WORKSPACEDIR/metadata.json"
{
  "description": "Kali Linux",
  "architecture": "amd64",
  $metadata
  "provider": "$provider"
}
EOF

## TODO:
##   - If ${version} is semantic versioning, then: config.vm.box_version = "${version}"
info "Generate Vagrantfile"
cat << EOF > "$WORKSPACEDIR/Vagrantfile"
# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_DEFAULT_PROVIDER'] = '$provider'

Vagrant.configure("2") do |config|
$vagrantfile
end
EOF

info "Compress to $image.box"
cd "$WORKSPACEDIR/"
tar -czf "$ARTIFACTDIR/$image.box" *

[ $keep -eq 1 ] || rm -rf "$WORKSPACEDIR/"

echo "$image.box" > "$ARTIFACTDIR/.artifacts"
