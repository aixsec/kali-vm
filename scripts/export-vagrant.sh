#!/bin/sh

set -eu

SCRIPTSDIR=$RECIPEDIR/scripts

info() { echo "INFO:" "$@"; }

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

cd $ARTIFACTDIR

rm -fr workspace
mkdir workspace

vagrantfile_hyperv='
  config.vm.provider :hyperv do |hyperv|
    hyperv.enable_virtualization_extensions = true
  end
'

vagrantfile_libvirt='
  ## REF: https://vagrant-libvirt.github.io/vagrant-libvirt/
  config.vagrant.plugins = "vagrant-libvirt"

  config.vm.provider :libvirt do |libvirt|
    libvirt.disk_bus = "virtio"
    libvirt.driver = "kvm"
    libvirt.video_vram = 256
  end
'

vagrantfile_virtualbox='
  config.vm.provider :virtualbox do |vb, override|
    vb.gui = false
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
  end
'

vagrantfile_vmware_desktop='
  ## REF: https://developer.hashicorp.com/vagrant/install/vmware
  config.vagrant.plugins = "vagrant-vmware-desktop"

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

case $variant in
    hyperv)
        provider=hyperv
        vagrantfile=$vagrantfile_hyperv
        info "Generate $image.vhdx"
        qemu-img convert -O vhdx $image.raw $image.vhdx
        mkdir workspace/"Virtual Hard Disks"
        mkdir workspace/"Virtual Machines"
        mv $image.vhdx workspace/"Virtual Hard Disks"/
touch "${image}.xml" #!!!
        mv "${image}.xml" workspace/"Virtual Machines"/
        ;;
    qemu)
        provider=libvirt
        vagrantfile=$vagrantfile_libvirt
        info "Generate $image.qcow2"
        qemu-img convert -O qcow2 $image.raw $image.qcow2
        mv $image.qcow2 workspace/
        metadata='"disks": [{"format": "qcow2", "path": "'$image'.qcow2"}],'
        ;;
    virtualbox)
        provider=virtualbox
        vagrantfile=$vagrantfile_virtualbox
        info "Generate $image.vmdk, $image.ovf and $image.mf"
        $SCRIPTSDIR/export-ovf.sh $image
        mv $image.vmdk $image.ovf $image.mf workspace/
        ;;
    vmware)
        provider=vmware_desktop
        vagrantfile=$vagrantfile_vmware_desktop
        info "Generate $image.vmdk"
        qemu-img convert -O vmdk -o subformat=twoGbMaxExtentSparse \
            $image.raw workspace/$image.vmdk
        info "Generate $image.vmx"
        $SCRIPTSDIR/generate-vmx.sh workspace/$image.vmdk
        ;;
    *)
        echo "ERROR: Unsupported variant '$variant'"
        exit 1
        ;;
esac

[ $keep -eq 1 ] || rm -f $image.raw

info "Vagrant provider: $provider"

cd workspace

## $ vagrant box list -i
info "Generate info.json"
cat << EOF | python3 -m json.tool > info.json
{
  "author": "Kali Linux",
  "homepage": "https://www.kali.org/",
  "build-script": "https://gitlab.com/kalilinux/build-scripts/kali-vm",
  "vagrant-cloud": "https://portal.cloud.hashicorp.com/vagrant/discover/kalilinux"
}
EOF

info "Generate metadata.json"
cat << EOF | python3 -m json.tool > metadata.json
{
  "architecture": "amd64",
  ${metadata}
  "provider": "${provider}"
}
EOF

info "Generate Vagrantfile"
cat << EOF > Vagrantfile
# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_DEFAULT_PROVIDER'] = '${provider}'

Vagrant.configure("2") do |config|
${vagrantfile}
end
EOF

info "Compress to $image.box"
tar -czf $image.box *

mv $image.box ../
cd ../

[ $keep -eq 1 ] || rm -fr workspace/

echo "$image.box" > .artifacts
