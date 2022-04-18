## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "generated_ssh_private_key" {
  value     = tls_private_key.public_private_key_pair.private_key_pem
  sensitive = true
}

output "redis_master_public_ip_address" {
  value = {for i in range(var.redis_master_count) : i => data.oci_core_vnic.redis_master_vnic[i].public_ip_address}
}

output "redis_master_private_ip_address" {
  value = {for i in range(var.redis_master_count) : i => data.oci_core_vnic.redis_master_vnic[i].private_ip_address}
}

output "redis_replica_public_ip_address" {
  value = {for i in range(var.redis_replica_count * var.redis_master_count) : (i + var.redis_master_count) => data.oci_core_vnic.redis_replica_vnic[i].public_ip_address}
}

output "redis_replica_private_ip_address" {
value = {for i in range(var.redis_replica_count * var.redis_master_count) : (i + var.redis_master_count) => data.oci_core_vnic.redis_replica_vnic[i].private_ip_address}
}

output "redis_password" {
  value = random_string.redis_password.result
}