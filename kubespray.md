Starting from a new project definition on ComputeCanada's west cloud

## Prerequisites
### Python / Ansible / Terraform
Download an up to date RC file from the project overview page and source it so
that we can authenticate to the openstack API. Terraform will need a few extra
variables as well. There's an init script in the root of this repository which
will look for openrc.sh with the correct variables for project etc. and will
prompt you for your openstack credentials

```
  . init.sh
```

### Terraform

Terraform is used to define 3 VMs running CentOS 7 on a smallish flavour. The
variables.tf file defines defaults for some standard variables and these can be
overriden by setting the corresponding environment variable (e.g.
TF_VAR_os_password). If you have sourced the init.sh script above then you
should be ready to go. In most cases you can just run `terraform plan` to see
what actions will be taken, but you may need to run `terraform init` to grab the
openstack plugin (running terraform plan should inform you if that is the case).

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
inventory *should* be generated automatically as in the
contrib/terraform/openstack setup, but that isn't configured yet, so here is a
sample (my_inventory/inventory.ini)

```
manager1 ansible_ssh_host=10.0.0.16
node1    ansible_ssh_host=10.0.0.18
node2    ansible_ssh_host=10.0.0.17

[kube-master]
manager1

[etcd]
manager1
node1
node2

[kube-node]
manager1
node1
node2

[k8s-cluster:children]
kube-node
kube-master
```

I tend to add the local IP addresses to .ssh/config as bastien ssh clients
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
  $ ansible -i ./inventory.ini -b -m command -a 'w' all
  $ ansible -i ./inventory.ini -b -m yum -a 'name=* state=latest' all
  $ ansible -i ./inventory.ini -b -m command -a 'reboot' all
```

There is also a playbook to update ssh keys and perform some other housekeeping
tasks
``` 
  $ cd ansible
  $ ansible-playbook plays/k8s.yml
```

## kubespray

### Deploy
If all has gone well, deploy from the kubespray directory with something like
```
$ ansible-playbook -i inventory/inventory.ini cluster.yml -b -v
```

The deploy can run for quite a ong time (10-15 minutes) and will report status
for each of the tasks defined in the kubespray playbooks. When it is finished,
log in to the master node and check the cluster status

```
 $ kubectl config view
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: REDACTED
    server: https://10.0.0.16:6443
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
master1   Ready     master,node   7m        v1.8.4+coreos.0
node1     Ready     node          7m        v1.8.4+coreos.0
node2     Ready     node          7m        v1.8.4+coreos.0
```

If things are showing as ready, proceed with testing out the kubernetes
deployment.

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
