Starting from a new project definition on cybera's RAC

## Prerequisites
### Python / Ansible / Terraform
Download an up to date RC file from the project overview page and source it so
that we can authenticate to the openstack API. Terraform will need a few extra
variables as well.

```
#!/usr/bin/env bash

# To use an OpenStack cloud you need to authenticate against the Identity
# service named keystone, which returns a **Token** and **Service Catalog**.
# The catalog contains the endpoints for all services the user/tenant has
# access to - such as Compute, Image Service, Identity, Object Storage, Block
# Storage, and Networking (code-named nova, glance, keystone, swift,
# cinder, and neutron).
#
# *NOTE*: Using the 2.0 *Identity API* does not necessarily mean any other
# OpenStack API is version 2.0. For example, your cloud provider may implement
# Image API v1.1, Block Storage API v2, and Compute API v2.0. OS_AUTH_URL is
# only for the Identity API served through keystone.
export OS_AUTH_URL=https://keystone-yyc.cloud.cybera.ca:5000/v2.0

# With the addition of Keystone we have standardized on the term **tenant**
# as the entity that owns the resources.
export OS_TENANT_ID=d22d1e3f28be45209ba8f660295c84cf
export OS_TENANT_NAME="jupyter-dev"

# unsetting v3 items in case set
unset OS_PROJECT_ID
unset OS_PROJECT_NAME
unset OS_USER_DOMAIN_NAME
unset OS_INTERFACE

# In addition to the owning entity (tenant), OpenStack stores the entity
# performing the action as the **user**.
export OS_USERNAME="ifallison@gmail.com"

# If your configuration has multiple regions, we set that information here.
# OS_REGION_NAME is optional and only valid in certain environments.
export OS_REGION_NAME="Calgary"
# Don't leave a blank variable, unset it if it was empty
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi

export OS_ENDPOINT_TYPE=publicURL
export OS_IDENTITY_API_VERSION=2

KEYFILE="./cybera.gpg" 
if [ -x "/usr/bin/gpg2" ] ; then
    GPG2="/usr/bin/gpg2"
elif [ -x "/usr/local/bin/gpg2" ] ; then
    GPG2="/usr/local/bin/gpg2"
else
    echo "Can't find GPG2, not setting OS_PASSWORD"
fi
OS_PASSWORD=$(${GPG2} -d ${KEYFILE})
export OS_PASSWORD


export TF_VAR_os_cybera_password=${OS_PASSWORD}
ulimit -n 1024
clear
```
Source all of the above
```
  $ . init-ian
```

### Terraform

Because of permissions not granted to us inside openstack we have to create the
infrastructure ourselves. We can make some guesses based on the
contrib/terraform/openstack configuration
```
provider "openstack" {
  user_name    = "${lookup(var.os_cybera, "user_name")}"
  password     = "${var.os_cybera_password}"
  auth_url     = "${lookup(var.os_cybera, "auth_url")}"
  tenant_name  = "${lookup(var.os_cybera, "tenant_name")}"
  tenant_id    = "${lookup(var.os_cybera, "tenant_id")}"
  region       = "${lookup(var.os_cybera, "region")}"
}

resource "openstack_networking_floatingip_v2" "fip_1" {
  pool         = "public"
}

resource "openstack_networking_floatingip_v2" "fip_2" {
  pool         = "public"
}

resource "openstack_compute_floatingip_associate_v2" "fip_1" {
  floating_ip = "${openstack_networking_floatingip_v2.fip_1.address}"
  instance_id = "${openstack_compute_instance_v2.master1.id}"
  fixed_ip = "${openstack_compute_instance_v2.master1.network.0.fixed_ip_v4}"
}

resource "openstack_compute_floatingip_associate_v2" "fip_2" {
  floating_ip = "${openstack_networking_floatingip_v2.fip_2.address}"
  instance_id = "${openstack_compute_instance_v2.master2.id}"
  fixed_ip = "${openstack_compute_instance_v2.master2.network.0.fixed_ip_v4}"
}

resource "openstack_compute_instance_v2" "master1" {
  name            = "master1"
  image_id        = "10076751-ace0-49b2-ba10-cfa22a98567d"
  flavor_id       = "2"
  key_pair        = "id_cybera_openstack"
  security_groups = ["default","ssh","ping"]
  user_data = "${var.cloudconfig_default_user}"
  network {
    name = "k8s-network"
    fixed_ip_v4 = "192.168.180.90"
  }
}

resource "openstack_compute_instance_v2" "master2" {
  name            = "master2"
  image_id        = "10076751-ace0-49b2-ba10-cfa22a98567d"
  flavor_id       = "2"
  key_pair        = "id_cybera_openstack"
  security_groups = ["default","ssh","ping"]
  user_data = "${var.cloudconfig_default_user}"
  network {
    name = "k8s-network"
    fixed_ip_v4 = "192.168.180.91"
  }
}

resource "openstack_compute_instance_v2" "node1" {
  name            = "node1"
  image_id        = "10076751-ace0-49b2-ba10-cfa22a98567d"
  flavor_id       = "2"
  key_pair        = "id_cybera_openstack"
  security_groups = ["default","ssh","ping"]
  user_data = "${var.cloudconfig_default_user}"
  network {
    name = "k8s-network"
    fixed_ip_v4 = "192.168.180.93"
  }
}

output "ip" {
  value = "${openstack_networking_floatingip_v2.fip_1.address}"
  value = "${openstack_networking_floatingip_v2.fip_2.address}"
}
```

Along with the corresponding variables.tf
```
variable "os_cybera_password" {}
variable "os_cybera" {
  type="map"
  default = {
    "user_name" = "ifallison@gmail.com"
    "project_name" = "jupyter-dev"
    "tenant_name" = "jupyter-dev"
    "tenant_id" = "d22d1e3f28be45209ba8f660295c84cf"
    "auth_url" = "https://keystone-yyc.cloud.cybera.ca:5000/v2.0"
    "region" = "Calgary"
  }
}

variable "cloudconfig_default_user" {
  type = "string"
  default = <<EOF
#cloud-config
system_info:
  default_user:
    name: ptty2u
EOF
}
```

This config should be able to use TF_VAR_os_cybera_password environment
variable to retrieve the password

Once the machines are deployed we need to take care of some initialization
tasks, most of the can be done via ansible, but we will want an inventory. The
inventory *should* be generated automatically as in the
contrib/terrafor/openstack setup, but that isn't configured yet, so here is a
sample 

```
# ## Configure 'ip' variable to bind kubernetes services on a
# ## different ip than the default iface
manager1 ansible_ssh_host=192.168.180.90
manager2 ansible_ssh_host=192.168.180.91
node1    ansible_ssh_host=192.168.180.93
# node4 ansible_ssh_host=95.54.0.15  # ip=10.3.0.4
# node5 ansible_ssh_host=95.54.0.16  # ip=10.3.0.5
# node6 ansible_ssh_host=95.54.0.17  # ip=10.3.0.6

# ## configure a bastion host if your nodes are not directly reachable
# bastion ansible_ssh_host=162.246.156.163

[kube-master]
manager1
manager2

[etcd]
manager1
manager2
node1

[kube-node]
manager1
manager2
node1

[k8s-cluster:children]
kube-node
kube-master
```

Then take care of some prelim tasks

  * sudo requiretty
  * yum update (exclude dhclient and dhpc*)
  * rm /etc/motd
  * disable host firewalls (probably the default)
  * turn swap off

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

## SSH/Access
I've defined a private network for these hosts (192.168.180.0/24) which isn't
routable so we will use one of the manager nodes as a bastien host for connecting
```
  $ vi ~/.ssh/config
...
Host 192.168.180.*
    User ptty2u
    ProxyCommand ssh -l ptty2u 162.246.156.163 -W %h:%p 
    IdentityFile ~/.ssh/id_cybera_openstack
    StrictHostKeyChecking no
```

### Deploy
If all has gone well, deploy from the kubespray directory with something like
```
$ ansible-playbook -i inventory/inventory.ini cluster.yml -b -v
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


