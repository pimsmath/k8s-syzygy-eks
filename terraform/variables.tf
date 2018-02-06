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

