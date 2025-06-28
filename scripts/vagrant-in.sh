#!/usr/bin/env sh
## REF: https://www.vagrantup.com/docs/boxes/base.html

username=${1:-vagrant}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

info() { echo "INFO:" "$@"; }

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

## Root Password: "vagrant"
info "Set root password"
echo "root:${username}" | chpasswd

## "vagrant" User
info "Create ${username} user"
#useradd -m -G ${username} ${username}
usermod -aG ${username} ${username}
info "Set ${username} password"
echo "${username}:${username}" | chpasswd
info "Set ${username} insecure public SSH key"
mkdir -pv /home/${username}/.ssh
wget -O /home/${username}/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub
chmod -v 0700 /home/${username}/.ssh/
chmod -v 0600 /home/${username}/.ssh/authorized_keys
chown -Rv ${username}:${username} /home/${username}/.ssh/

## Password-less Sudo
info "Set password-less sudo"
echo "${username} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${username}
chmod -v 0440 /etc/sudoers.d/${username}

## SSH Tweaks
info "Do SSH tweaks"
grep -w '^UseDNS' /etc/ssh/sshd_config || echo 'UseDNS no' >> /etc/ssh/sshd_config
systemctl enable ssh

## Fix the DHCP NAT
info "Do DHCP tweaks"
#echo -e "auto eth0\niface eth0 inet dhcp" >> /etc/network/interfaces   # Legacy
cat <<EOF>/etc/systemd/network/20-wired.network
[Match]
Name=eth0

[Network]
DHCP=yes
EOF
systemctl enable systemd-networkd
