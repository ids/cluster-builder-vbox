#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

echo '>>> Installing base dependencies'
sudo apt -y install libssl-dev apt-transport-https ca-certificates \
git wget chrony curl bash tar nano gnupg2 software-properties-common

echo '>>> Appending Authorized Keys for [sysop]'
mkdir -p /home/sysop/.ssh
chown -R sysop:sysop /home/sysop/.ssh
chmod 700 /home/sysop/.ssh
cp /tmp/authorized_keys /home/sysop/.ssh/
chown -R sysop:sysop /home/sysop/.ssh/authorized_keys
chmod 600 /home/sysop/.ssh/authorized_keys

echo '>>> Updating Ubuntu'
sudo apt update 
sudo apt-get upgrade -y


#echo '>>> Install VBox Guest Additions'
sudo apt install -y virtualbox-guest-utils virtualbox-guest-x11

sudo cat <<EOF > ~/00-installer-config.yaml
network:
  ethernets:
    enp0s3:
      dhcp4: true
      dhcp-identifier: mac
    enp0s8:
      dhcp4: no
      dhcp-identifier: mac
      addresses: [192.168.56.70/24]
      nameservers:
        addresses: [8.8.8.8,8.8.4.4]
  version: 2
EOF

sudo rm /etc/netplan/00-installer-config.yaml
sudo cp ~/00-installer-config.yaml /etc/netplan/00-installer-config.yaml

echo '>>> Netplan'
sudo cat /etc/netplan/00-installer-config.yaml
sudo netplan apply

sudo cat <<EOF > ~/etchosts_concat
127.0.0.1  localhost
EOF

sudo cat ~/etchosts_concat >> /etc/hosts

echo '>>> /etc/hosts'
sudo cat /etc/hosts

echo '>>> Install iSCSI Target'
sudo apt-get install tgt targetcli-fb -y
sudo systemctl stop tgt

sudo mkdir /var/lib/iscsi_disks 
sudo dd if=/dev/zero of=/var/lib/iscsi_disks/disk01.img count=0 bs=1 seek=10G

sudo cat <<EOF > /etc/tgt/conf.d/target01.conf 
# create new
# if you set some devices, add <target>-</target> and set the same way with follows
# naming rule : [ iqn.(year)-(month).(reverse of domain name):(any name you like) ]

<target iqn.2022-04.world.srv:dlp.target01>
    # provided devicce as a iSCSI target
    backing-store /var/lib/iscsi_disks/disk01.img
    # iSCSI Initiator's IQN you allow to connect
    initiator-name iqn.2022-04.world.srv:node01.initiator01
    # authentication info ( set anyone you like for "username", "password" )
    incominguser username password
</target> 
EOF

sudo systemctl restart tgt 
sudo tgtadm --mode target --op show 
