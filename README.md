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
bash clusterctl eg/k8s [start | stop | pause | resume | savestate]
```

The __clusterctl__ script uses ansible and the hosts file to easily suspend a functioning cluster and resume it later, which is very useful in development.


## Addons
There are a number of additional components in the __addons__ folder that can be useful.

### Ingress NGINX

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.5.1/deploy/static/provider/cloud/deploy.yaml
```
[NGINX Test Instructions](https://kubernetes.github.io/ingress-nginx/deploy/#local-testing)

### NFS Provisioner
This is setup to use one of the local worker nodes as an NFS storage location.

Each worker node has a directory __/storage/nfs-provisioner__ and will be used to store the PVCs depending on which node the POD is deployed.

It creates a StorageClass called __nfs-dynamic__.

### Metallb
The IP pool is set to a range within the VirtualBox __host only__ default network of 192.168.56.0/24, and uses the range 30-45 for the local pool.  This will allow any services using __LoadBalancer__ to get a dedicated address on the host only network.

### MySQL
A quick client configuration that leverages both the Metallb and NFS Provisioner.

### ELK
Not using `helm` is always refreshing:

```
kubectl apply -f elastic.yaml 
kubectl apply -f filebeat.yaml 
kubectl apply -f logstash.yaml 
kubectl apply -f kibana.yaml
```

> Everything goes into the `kube-system` namespace.  The ElasticSearch index is prefixed with `k8s-logs` as configured in the __Filebeat__ config yaml.

### Kill a PVC Stuck Terminating

```
kubectl patch pvc {PVC_NAME} -p '{"metadata":{"finalizers":null}}'
```

You need to patch the PVC to set the “finalizers” setting to null, this allows the final unmount from the node, and the PVC can be deleted.


