output "id" {
  description = "Endpoint for EKS control plane."
  value       = "${azurerm_kubernetes_cluster.jhub.id}"
}

output "kube_config" {
  description = "Kubernetes config file (raw)"
  value       = "${azurerm_kubernetes_cluster.jhub.kube_config_raw}"
}

output "client_key" {
  value = "${azurerm_kubernetes_cluster.jhub.kube_config.0.client_key}"
}

output "client_certificate" {
  value = "${azurerm_kubernetes_cluster.jhub.kube_config.0.client_certificate}"
}

output "cluster_ca_certificate" {
  value = "${azurerm_kubernetes_cluster.jhub.kube_config.0.cluster_ca_certificate}"
}

output "host" {
  value = "${azurerm_kubernetes_cluster.jhub.kube_config.0.host}"
}
