## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

#data "oci_identity_tag_namespace" "redis_manager_tag_namespace" {
#    name = var.redis_manager_tag_namespace_name
#}

data "oci_identity_tag" "redis_manager_tag" {
    tag_name = var.redis_manager_tag_name
    tag_namespace_id = var.redis_manager_tag_namespace_id
}