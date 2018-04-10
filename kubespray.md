Starting from a new project definition on an OpenStack installation

## Prerequisites
### Python / Ansible / Terraform
Download an up to date RC file from the project overview page and source it so
that we can authenticate to the openstack API. Terraform will need a few extra
variables as well. There's an init script in the root of this repository which
will look for openrc.sh with the correct variables for project etc. and will
prompt you for your openstack credentials

```
  . init.sh cybera
```

### Terraform

Terraform is used to define 3 VMs running CentOS 7 on a smallish flavour. The
variables.tf file defines defaults for some standard variables which can be
overridden by setting the corresponding environment variable (e.g.
TF_VAR_os_password). If you have sourced the init.sh script above then you
should be ready to go. In most cases you can just change to the terraform
directory and run `terraform plan` to see what actions will be taken, but you
may need to run `terraform init` to grab the openstack plugin (running terraform
plan should inform you if that is the case).

```
  $ terraform plan
  $ terraform apply
```

Terraform will create the resources defined in k8s-syzygy.tf and report back the
floating IP of the master node. Assign a name for this in DNS (e.g.
k8s1.syzygy.ca)

### Ansible

Once the machines are deployed we need to take care of some initialization
tasks, most of the can be done via ansible, but we will want an inventory. The
inventory construction process is described on the [kubespray
README.md](https://github.com/kubernetes-incubator/kubespray/blob/master/README.md).
Following that you should have an inventory in inventory/mycluster along with
some configuration variables.

```
$ cd kubespray
$ cp -rpf inventory/sample inventory/mycluster
# Check the IPS via openstack GUI or CLI
$ declare -a IPS=(10.0.0.172 10.0.0.171 10.0.0.170)
$ CONFIG_FILE=inventory/mycluster/hosts.ini python3
  contrib/inventory_builder/inventory.py ${IPS[@]}

$ vi inventory/mycluster/group_vars/all.yml
 +bootstrap_os: centos

$ vi inventory/mycluster/group_vars/k8s-cluster.yml
 +kube_network_plugin: flannel

$ vi inventory/mycluster/hosts.ini
[all]
master1 	 ansible_host=10.0.0.172 ip=10.0.0.172
node1 	 ansible_host=10.0.0.171 ip=10.0.0.171
node2 	 ansible_host=10.0.0.170 ip=10.0.0.170

[kube-master]
master1

[kube-node]
master1
node1
node2

[etcd]
master1
node1
node2

[k8s-cluster:children]
kube-node
kube-master

[vault]
master1
node1
node2

+[gfs-cluster]
+master1 disk_volume_device_1=/dev/vdc
+node1   disk_volume_device_1=/dev/vdc
+node2   disk_volume_device_1=/dev/vdc

+[network-storage:children]
+gfs-cluster
```

Add the local IP addresses to .ssh/config as bastien ssh clients
```
# kubernetes on CC
Host 10.0.0.*
    User ptty2u
    ProxyCommand ssh -l ptty2u k8s1.syzygy.ca -W %h:%p
    IdentityFile ~/.ssh/id_cc_openstack
    StrictHostKeyChecking no
```

Now run ansible to update the hosts
```
  $ cd ansible
  $ ansible -i hosts.ini -b -m command -a 'w' all
  $ ansible -i hosts.ini -b -m yum -a 'name=* state=latest' all
  $ ansible -i hosts.ini -b -m command -a 'reboot' all
```

There is also a playbook to update ssh keys and perform some other housekeeping
tasks
``` 
  $ ansible-playbook -i hosts.ini plays/k8s.yml
  $ ansible -i hosts.ini -b -m command -a 'reboot' all
```
The final reboot is needed to pick up the new kernel installed in the k8s.yml
playbook.

## kubespray

### Deploy
Our kubespray deployment is fairly vanilla, but since we've had problems with
the docker storage backend we will use overlay2 (we have a 4.4 kernel). Be
CAREFUL to use the right device in the config file below.

```
  $ vi ./inventory/mycluster/group_vars/docker-storage.yml
---
docker_container_storage_setup_version: v0.6.0
docker_container_storage_setup_profile_name: kubespray
docker_container_storage_setup_storage_driver: overlay2
docker_container_storage_setup_devs: /dev/sdb

  $ cd kubespray
  $ ansible-playbook -i inventory/mycluster/hosts.ini -b -v cluster.yml
```

The deploy can run for quite a long time (10-15 minutes) and will report status
for each of the tasks defined in the kubespray playbooks. When it is finished,
log in to the master node and check the cluster status

```
 $ kubectl config view
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: REDACTED
    server: https://192.168.180.117:6443
  name: cluster.local
contexts:
- context:
    cluster: cluster.local
    user: admin-cluster.local
  name: admin-cluster.local
current-context: admin-cluster.local
kind: Config
preferences: {}
users:
- name: admin-cluster.local
  user:
    client-certificate-data: REDACTED
    client-key-data: REDACTED

  $ kubectl get nodes
NAME      STATUS    ROLES         AGE       VERSION
master1   Ready     master,node   2m        v1.9.5+coreos.0
node1     Ready     node          2m        v1.9.5+coreos.0
node2     Ready     node          2m        v1.9.5+coreos.0
```

## Distributed Storage
A lot of what kubernetes does relies on having distributed storage. There are
various options, but for now, we will stick to glusterfs. On top of gluster, we
use heketi as a service to allow kubernetes to control allocation and mangement
of storage. 
```
  $ cd ansible
  $ ansible-playbook -i hosts.ini -b -v storage.yml

  $ heketi cluster list
    Clusters:
    Id:73459fb776036c004c40480df0cfa184
  $ heketi-cli cluster info 73459fb776036c004c40480df0cfa184
    Cluster id: 73459fb776036c004c40480df0cfa184
    Nodes:
    a3e970959dc93575468e4736ac6e9904
    Volumes:
  $ kubectl get storageclass
NAME                PROVISIONER               AGE
generic (default)   kubernetes.io/glusterfs   30m
[root@master1 ~]# kubectl describe storageclass
Name:            generic
IsDefaultClass:  Yes
Annotations:     kubectl.kubernetes.io/last-applied-configuration={"apiVersion":"storage.k8s.io/v1","kind":"StorageClass","metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"},"name":"generic","namespace":""},"parameters":{"restauthenabled":"false","resturl":"http://master1:8880"},"provisioner":"kubernetes.io/glusterfs","reclaimPolicy":"Retain"}
,storageclass.kubernetes.io/is-default-class=true
Provisioner:    kubernetes.io/glusterfs
Parameters:     restauthenabled=false,resturl=http://master1:8880
ReclaimPolicy:  Retain
Events:         <none>
```

If things are showing as ready, proceed with testing out the kubernetes
deployment.

### Gluster

It might be necessary to add distributed storage to the cluster for some
tasks. We can do this by adding volumes to the hosts in openstack then using
the contrib gluster playbook with the following modifications to the
inventory
```
+
+[gfs-cluster]
+manager1 disk_volume_device_1=/dev/sdc
+manager2 disk_volume_device_1=/dev/sdc
+node1 disk_volume_device_1=/dev/sdc
+
+[network-storage:children]
+gfs-cluster
+
```
(the device name is as reported by openstack, ideally this should be added to
our terraform state.)

```
ansible-playbook -b --become-user=root --user=ptty2u -i
../my_inventory/inventory.ini ./contrib/network-storage/glusterfs/glusterfs.yml
```

If you get errors with out of date IP addresses, try adding `--flush-cache` to
remove the facts cached by ansible.

Once it is running, you should be able to create, use and destroy gluster
volumes
```
 manager1$ gluster volume create test replica 3 transport tcp 10.0.0.16:/mnt/xfs-drive-gluster/volume1 10.0.0.18:/mnt/xfs-drive-gluster/volume1 10.0.0.17:/mnt/xfs-drive-gluster/volume1
 manager1$ gluster volume start
 manager1$ mkdir /tmp/gluster
 manager1$ mount -t glusterfs 10.0.0.16:test /tmp/gluster
 manager1$ touch /mnt/gluster/file
 node1$ mkdir /tmp/gluster
 node1$ mount -t glusterfs 10.0.0.18:test /tmp/gluster
 node1$ ls /tmp/gluster
 file
 
 node1$ umount /tmp/gluster
 manager1$ umount /tmp/gluster
 manager1$ gluster volume stop test
 manager1$ gluster volume delete test
 ```


## Other notes

The notes below this point may not be relevant, they mostly relate to problems
we've seen on other installations.

### Openstack

We assume that you have a project available inside openstack. There is some
preliminary setup required for the network (see the [kubespray-cli
README](https://github.com/kubespray/kubespray-cli).
```
  $ neutron net-create k8s-network
  $ neutron subnet-create --name k8s-subnet --dns-nameserver 8.8.8.8
  --enable-dhcp --allocation_pool "start=192.168.180.100,end=192.168.180.200"
  k8s-network 192.168.180.0/24
  $ neutron router-create k8s-router
```

Set the gateway network, N.B. I had to ask one of the cluster admins to do this
for me because it pulls an IP out of their limited pool.
```
  $ neutron router-gateway-set k8s-router external_network
```

### Heketi
Heketi isn't too complicated, but may be unfamiliar. I found the following steps
useful when debugging

Stop the service and tidy up
```
  $ systemctl stop heketi
  $ rm -rf /var/lib/heketi/heketi.db
  $ wipefs -a -f /dev/sdc
  $ ssh -i /etc/heketi/heketi_key ptty2u@node1 sudo wipefs -a -f /dev/sdc
  $ ssh -i /etc/heketi/heketi_key ptty2u@node2 sudo wipefs -a -f /dev/sdc
  $ chown -R heketi:heketi /var/lib/heketi
  $ systemctl start heketi
  $ heketi-cli topology load --json=/etc/heketi/heketi.json # CHECK DEVICES
  $ heketi-cli volime create --size=1
    Name: vol_523804471d39f006a6490ba45e354296
    Size: 1
    Volume Id: 523804471d39f006a6490ba45e354296
    Cluster Id: c22267d8338832db6dea28514ac40c6c
    Mount: 192.168.180.121:vol_523804471d39f006a6490ba45e354296
    Mount Options: backup-volfile-servers=192.168.180.122,192.168.180.123
    Durability Type: replicate
    Distributed+Replica: 3
  $ heketi-cli volume list
    Id:523804471d39f006a6490ba45e354296    Cluster:c22267d8338832db6dea28514ac40c6c    Name:vol_523804471d39f006a6490ba45e354296
  $ heketi-cli volume delete 523804471d39f006a6490ba45e354296
    Volume 523804471d39f006a6490ba45e354296 deleted
```

As long as this stuff works, you should be ready to define a storage class in
kubernetes.

### Kubernetes Storage
  ** Try NFS to see if we can do things simpler~ **

Kubernetes pod storage works on a system of PersistentVolumes and
PersinstentVolumeClaims. Once you have heketi up the idea is to define a
storageclass around heketi and set it to be the default. When a pod needs
persistent storage, it then makes a claim and heketi takes care of satisfying
it. Here is our current storageclass
```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: generic
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/glusterfs
reclaimPolicy: Retain
parameters:
  resturl: "http://master1:8880"
  restauthenabled: "false"
```

And here is a sample claim
```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: myclaim-1
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Assuing heketi and gluster are running and the storageclass has been defined
```
  $ kubectl apply -f claim.yml
  $ kubectl get pvc
NAME        STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
myclaim-1   Bound     pvc-34d61d0b-3d00-11e8-9614-fa163ed00a15   2G         RWO            generic        4m
  $ kubectl describe pvc
Name:          myclaim-1
Namespace:     default
StorageClass:  generic
Status:        Bound
Volume:        pvc-34d61d0b-3d00-11e8-9614-fa163ed00a15
Labels:        <none>
Annotations:   kubectl.kubernetes.io/last-applied-configuration={"apiVersion":"v1","kind":"PersistentVolumeClaim","metadata":{"annotations":{},"name":"myclaim-1","namespace":"default"},"spec":{"accessModes":["ReadWr...
               pv.kubernetes.io/bind-completed=yes
               pv.kubernetes.io/bound-by-controller=yes
               volume.beta.kubernetes.io/storage-provisioner=kubernetes.io/glusterfs
Finalizers:    []
Capacity:      2G
Access Modes:  RWO
Events:
  Type     Reason              Age              From                         Message
  ----     ------              ----             ----                         -------
  Warning  ProvisioningFailed  4m (x4 over 4m)  persistentvolume-controller  Failed to provision volume with StorageClass "generic": create volume error: error creating volume Volume group "vg_be85e2d27902d056a4ce4595a8586644" not found
  Cannot process volume group vg_be85e2d27902d056a4ce4595a8586644
  Normal  ProvisioningSucceeded  3m  persistentvolume-controller  Successfully provisioned volume pvc-34d61d0b-3d00-11e8-9614-fa163ed00a15 using kubernetes.io/glusterfs

 $ kubectl delete pvc myclaim-1
 $ kubectl delete pv pvc-34d61d0b-3d00-11e8-9614-fa163ed00a15
```
