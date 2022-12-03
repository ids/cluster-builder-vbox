Cluster Builder for VirtualBox
==============================

Multi-node Kubernetes clusters in VirtualBox.

>Still in the early stages...

>There must be over a half dozen different ways to get K8s on your desktop these days, but none of them are a very good likeness to real kubernetes.  Nearly all are single node master workloads - and that isn't really a cluster.  I found myself missing the true K8s experience I used to have with [cluster builder](https://github.com/ids/cluster-builder).

>VMware jumped the shark.  No point in looking back.  

>It was time to do a VirtualBox edition.

## Requirements:

- [VirtualBox 6.x](https://download.virtualbox.org/virtualbox/6.0.24/VirtualBox-6.0.24-139119-OSX.dmg) (packer doesn't play well with 7.x yet)
- __Packer__ (brew install packer)
- __Ansible__ (brew install ansible)
- __kubectl__ (brew install kubectl)

This has been tested on a __macOS__ host thus far and likely won't migrate much further.

## Cluster Config Files
In the style of __cluster-builder__ the ansible inventory host files are the K8s configuration files, and are stored in:

```
 clusters/[org folder]/[cluster name folder]/hosts
```

For example:

```
#clusters/local/k8s/hosts

[all:vars]
cluster_name=k8s-local
remote_user=sysop

network_mask=255.255.255.0
network_cidr=/24
network_dn=vm.idstudios.io

[k8s_masters]
k8s-m1.vm.idstudios.io ansible_host=192.168.56.50 numvcpus=2 memsize=2524

[k8s_workers]
k8s-w1.vm.idstudios.io ansible_host=192.168.56.60 numvcpus=2 memsize=2524
k8s-w2.vm.idstudios.io ansible_host=192.168.56.61 numvcpus=2 memsize=2524

```

There is an example file in __clusters/eg__

## Create a Kubernetes Cluster

```
bash build-cluster eg/k8s
```

This has 2-3 phases:

1. Packer build of cluster node image (only happens once)
2. Ansible deployment of cluster node image to VirtualBox nodes defined in hosts file
3. Ansible deployment of Kubernetes to nodes

After the cluster node is built, stage one is bypassed.  To rebuild the cluster-node (which takes some time), you can remove the image:

```
rm -rf node-packer/images
```

And then stage one will repeat and a fresh __cluster-node.ova__ will be built by packer.

When the cluster has finished a message will be displayed with instructions for using the cluster.  The `kubeconfig` file is downloaded to the __cluster package folder__ (eg. eg/k8s), which you can then merge to your ~/.kube/config, or reference explicitly.


## Control Kubernetes Cluster VMs

```
bash control-cluster eg/k8s [start | stop | pause | resume | savestate]
```

This makes it easy to suspend a functioning cluster and resume it later, which is very useful in development.


## Notes

### Ingress NGINX

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.5.1/deploy/static/provider/cloud/deploy.yaml
```
[NGINX Test Instructions](https://kubernetes.github.io/ingress-nginx/deploy/#local-testing)