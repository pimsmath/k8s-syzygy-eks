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
