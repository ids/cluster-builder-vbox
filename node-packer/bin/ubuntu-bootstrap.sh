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

echo '>>> Disable Swap'
sudo swapoff --all

echo '>>> Enable Kernel Modules'
sudo modprobe overlay
sudo modprobe br_netfilter

echo '>>> Configure Sysctl'
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

echo '>>> Reload Sysctl'
sudo sysctl --system

echo '>>> Install K8s Repo'
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository --yes "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo add-apt-repository --yes multiverse
sudo apt update

echo '>>> Install K8s Binaries'
sudo apt-get install -y kubelet kubeadm kubectl

echo '>>> Install Containerd'
wget https://github.com/containerd/containerd/releases/download/v1.6.10/containerd-1.6.10-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-1.6.10-linux-amd64.tar.gz

# Add Docker repo
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install containerd
#sudo apt update
#sudo apt install -y containerd.io

sudo mkdir -p /etc/containerd/
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service

echo '>>> Install Runc'
wget https://github.com/opencontainers/runc/releases/download/v1.1.3/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

#echo '>>> Install CNI and configure Containerd service'
#wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
#sudo mkdir -p /opt/cni/bin
#sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.1.1.tgz

sudo systemctl daemon-reload

echo '>>> Start and Enable Containerd service'
sudo systemctl start containerd 
sudo systemctl enable containerd

echo '>>> Pre-seed node image with containers'
sudo kubeadm config images pull

#echo '>>> Install VBox Guest Additions'
sudo apt install -y virtualbox-guest-utils virtualbox-guest-x11

sudo cat <<EOF > ~/00-installer-config.yaml
network:
  ethernets:
    enp0s3:
      dhcp4: true
      dhcp-identifier: mac
    enp0s8:
      dhcp4: true
      dhcp-identifier: mac
  version: 2
EOF

sudo rm /etc/netplan/00-installer-config.yaml
sudo cp ~/00-installer-config.yaml /etc/netplan/00-installer-config.yaml

echo '>>> Netplan'
sudo cat /etc/netplan/00-installer-config.yaml
sudo netplan apply

echo '>>> /etc/hosts'
sudo cat /etc/hosts

echo '>>> Prep directory for NFS storage provisioner'
sudo mkdir -p /storage/nfs-provisioner
sudo chmod 777 -R /storage/nfs-provisioner

