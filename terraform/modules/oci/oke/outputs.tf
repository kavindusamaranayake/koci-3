output "cluster_id" {
  description = "OCID of the OKE cluster"
  value       = module.oke_cluster.id
}

output "node_pool_ids" {
  description = "List of node-pool OCIDs"
  value       = [for np in oci_containerengine_node_pool.node_pool : np.id]
}

output "app_nodes_nsg_id" {
  description = "OCID of the app nodes NSG"
  value       = module.app_nodes_nsg.nsg_id
}

output "kube_api_nsg_id" {
  description = "OCID of the kube-api NSG"
  value       = module.kube_api_nsg.nsg_id
}

output "kubernetes_endpoint" {
  description = "Kubernetes API private endpoint"
  value       = module.oke_cluster.private_endpoint
}