# Copyright (c) 2017, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

output "id" {
  description = "OCID of the created OKE cluster"
  value       = oci_containerengine_cluster.k8s_cluster.id
}

output "private_endpoint" {
  description = "Private control-plane endpoint"
  value       = one(oci_containerengine_cluster.k8s_cluster.endpoints).private_endpoint
}

output "endpoints" {
  value = one(oci_containerengine_cluster.k8s_cluster.endpoints)
}

output "oidc_discovery_endpoint" {
  value = oci_containerengine_cluster.k8s_cluster.open_id_connect_discovery_endpoint
}