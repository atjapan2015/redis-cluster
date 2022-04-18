## Copyright © 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# Get the latest Oracle Linux image
data "oci_core_images" "InstanceImageOCID" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.instance_os
  operating_system_version = var.linux_os_version
  shape                    = var.instance_shape

  filter {
    name   = "display_name"
    values = ["^.*Oracle[^G]*$"]
    regex  = true
  }
}

data "template_file" "key_script" {
  template = templatefile( "./scripts/sshkey.tpl", {
    ssh_public_key = tls_private_key.public_private_key_pair.public_key_openssh
  })
}

data "template_cloudinit_config" "cloud_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "ainit.sh"
    content_type = "text/x-shellscript"
    content      = data.template_file.key_script.rendered
  }
}

data "template_file" "redis_bootstrap_master_template" {
  template = templatefile("./scripts/redis_bootstrap_master.tpl", {
    count             = var.redis_master_count
    redis_prefix      = var.redis_prefix
    redis_domain      = var.redis_domain
    redis_version     = var.redis_version
    redis_port1       = var.redis_port1
    redis_port2       = var.redis_port2
    sentinel_port     = var.sentinel_port
    redis_password    = random_string.redis_password.result
    master_private_ip = data.oci_core_vnic.redis_master_vnic.*.private_ip_address
    master_fqdn       = data.oci_core_vnic.redis_master_vnic.*.hostname_label
  })
}

data "template_file" "redis_bootstrap_replica_template" {
  template = templatefile("./scripts/redis_bootstrap_replica.tpl", {
    redis_version  = var.redis_version
    redis_port1    = var.redis_port1
    redis_port2    = var.redis_port2
    sentinel_port  = var.sentinel_port
    redis_password = random_string.redis_password.result
  })
}

data "oci_core_vnic_attachments" "redis_master_vnics" {
  count               = var.redis_master_count
  compartment_id      = var.compartment_ocid
  availability_domain = var.availablity_domain_name
  instance_id         = oci_core_instance.redis_master[count.index].id
}

data "oci_core_vnic" "redis_master_vnic" {
  count   = var.redis_master_count
  vnic_id = data.oci_core_vnic_attachments.redis_master_vnics[count.index].vnic_attachments.0.vnic_id
}

data "oci_core_vnic_attachments" "redis_replica_vnics" {
  count               = var.redis_replica_count * var.redis_master_count
  compartment_id      = var.compartment_ocid
  availability_domain = var.availablity_domain_name
  instance_id         = oci_core_instance.redis_replica[count.index].id
}

data "oci_core_vnic" "redis_replica_vnic" {
  count   = var.redis_replica_count * var.redis_master_count
  vnic_id = data.oci_core_vnic_attachments.redis_replica_vnics[count.index].vnic_attachments.0.vnic_id
}

data "oci_identity_region_subscriptions" "home_region_subscriptions" {
  tenancy_id = var.tenancy_ocid
  filter {
    name   = "is_home_region"
    values = [true]
  }
}