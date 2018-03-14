variable "os_password" {}

# TF_VAR_os_username
variable "os_username" {
  default = "iana"
}

# TF_VAR_os_ssh_key
variable "os_ssh_key" {
  default = "id_cc_openstack"
}

# TF_VAR_os_tenant_name {
variable "os_tenant_name" {
  default = "ipm-500"
}

# TF_VAR_os_tenant_id {
variable "os_tenant_id" {
  default = "9f627f6d145f43f384c9b75c4cab207d"
}
# TF_VAR_os_project_name{
variable "os_project_name" {
  default = "ipm-500"
}

# TF_VAR_os_flavor_id {
variable "os_flavor_id" {
  default = "2ff7463c-dda9-4687-8b7a-80ad3303fd41"
}

# TF_VAR_os_default_network {
variable "os_default_network" {
  default = "ipm-500_network"
}

# TF_VAR_os_external_network {
variable "os_external_network" {
  default = "VLAN3337"
}

# TF_VAR_os_image_id {
variable "os_image_id" {
  default = "5088c906-1636-4319-9dcb-76ab92257731"
}
# TF_VAR_os_auth_url 
variable "os_auth_url" {
  default = "https://west.cloud.computecanada.ca:5000/v2.0"
}

# TF_VAR_os_region_name
variable "os_region_name" {
  default = "regionOne"
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

