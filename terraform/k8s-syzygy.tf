provider "openstack" {
  user_name    = "${var.os_username}"
  password     = "${var.os_password}"
  auth_url     = "${var.os_auth_url}"
  tenant_name  = "${var.os_tenant_name}"
  tenant_id    = "${var.os_tenant_id}"
  region       = "${var.os_region_name}"
}

resource "openstack_blockstorage_volume_v2" "gvol1" {
  name = "gvol1"
  size = 5
}

resource "openstack_blockstorage_volume_v2" "gvol2" {
  name = "gvol2"
  size = 5
}

resource "openstack_blockstorage_volume_v2" "gvol3" {
  name = "gvol3"
  size = 5
}

resource "openstack_compute_secgroup_v2" "ssh" {
  name        = "ssh"
  description = "ssh access"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "ping" {
  name        = "ping"
  description = "ICMP traffic"

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_networking_floatingip_v2" "fip_1" {
  pool = "VLAN3337"
}

resource "openstack_compute_floatingip_associate_v2" "fip_1" {
  floating_ip = "${openstack_networking_floatingip_v2.fip_1.address}"
  instance_id = "${openstack_compute_instance_v2.master1.id}"
}

resource "openstack_compute_volume_attach_v2" "gvol1" {
  instance_id = "${openstack_compute_instance_v2.master1.id}"
  volume_id = "${openstack_blockstorage_volume_v2.gvol1.id}"
}

resource "openstack_compute_volume_attach_v2" "gvol2" {
  instance_id = "${openstack_compute_instance_v2.node1.id}"
  volume_id = "${openstack_blockstorage_volume_v2.gvol2.id}"
}

resource "openstack_compute_volume_attach_v2" "gvol3" {
  instance_id = "${openstack_compute_instance_v2.node2.id}"
  volume_id = "${openstack_blockstorage_volume_v2.gvol3.id}"
}

resource "openstack_compute_instance_v2" "master1" {
  name            = "master1"
  image_id        = "${var.os_image_id}"
  flavor_id       = "${var.os_flavor_id}"
  key_pair        = "${var.os_ssh_key}"
  security_groups = ["default", "ssh", "ping"]
  user_data = "${var.cloudconfig_default_user}"
  network {
    name = "${var.os_default_network}"
  }
}

resource "openstack_compute_instance_v2" "node1" {
  name            = "node1"
  image_id        = "${var.os_image_id}"
  flavor_id       = "${var.os_flavor_id}"
  key_pair        = "${var.os_ssh_key}"
  security_groups = ["default", "ssh", "ping"]
  user_data = "${var.cloudconfig_default_user}"
  network {
    name = "${var.os_default_network}"
  }
}

resource "openstack_compute_instance_v2" "node2" {
  name            = "node2"
  image_id        = "${var.os_image_id}"
  flavor_id       = "${var.os_flavor_id}"
  key_pair        = "${var.os_ssh_key}"
  security_groups = ["default", "ssh", "ping"]
  user_data = "${var.cloudconfig_default_user}"
  network {
    name = "${var.os_default_network}"
  }
}

output "ip" {
  value = "${openstack_networking_floatingip_v2.fip_1.address}"
}
