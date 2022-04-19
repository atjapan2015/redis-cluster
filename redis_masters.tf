## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_core_instance" "redis_master" {
  count               = var.redis_master_count
  availability_domain = var.availablity_domain_name
  fault_domain        = "FAULT-DOMAIN-${count.index%3+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.redis_prefix}${count.index}"
  shape               = var.instance_shape

  dynamic "shape_config" {
    for_each = local.is_flexible_node_shape ? [1] : []
    content {
      memory_in_gbs = var.instance_flex_shape_memory
      ocpus         = var.instance_flex_shape_ocpus
    }
  }

  create_vnic_details {
    subnet_id        = data.oci_core_subnet.redis_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "${var.redis_prefix}${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.InstanceImageOCID.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.template_cloudinit_config.cloud_init.rendered
  }

  defined_tags = {
    "${var.redis_manager_tag_namespace_name}.${data.oci_identity_tag.redis_manager_tag.name}" = var.release
  }
}

