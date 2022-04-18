## Copyright (c) 2020, Oracle and/or its affiliates. 
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "null_resource" "redis_master_start_redis" {
  depends_on = [null_resource.redis_master_bootstrap, null_resource.redis_replica_bootstrap]
  count      = var.redis_master_count
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_master_vnic[count.index].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      script_path = "/home/opc/myssh.sh"
      agent       = false
      timeout     = "10m"
    }
    inline = [
      "echo '=== Starting REDIS on redis${count.index} node... ==='",
      "sudo -u root nohup /usr/local/bin/redis-server /etc/redis.conf > /tmp/redis-server.log &",
      "ps -ef | grep redis",
      "sleep 10",
      "sudo cat /tmp/redis-server.log",
      "echo '=== Started REDIS on redis${count.index} node... ==='"
    ]
  }
}

resource "null_resource" "redis_replica_start_redis" {
  depends_on = [null_resource.redis_master_start_redis]
  count      = var.redis_replica_count * var.redis_master_count
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_replica_vnic[count.index].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      script_path = "/home/opc/myssh.sh"
      agent       = false
      timeout     = "10m"
    }
    inline = [
      "echo '=== Starting REDIS on redis${count.index + var.redis_master_count} node... ==='",
      "sudo -u root nohup /usr/local/bin/redis-server /etc/redis.conf > /tmp/redis-server.log &",
      "ps -ef | grep redis",
      "sleep 10",
      "sudo -u root cat /tmp/redis-server.log",
      "echo '=== Started REDIS on redis${count.index + var.redis_master_count} node... ==='"
    ]
  }
}

resource "null_resource" "redis_master_master_list" {
  depends_on = [null_resource.redis_master_start_redis]
  count      = var.redis_master_count
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_master_vnic[0].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      script_path = "/home/opc/myssh${count.index}.sh"
      agent       = false
      timeout     = "10m"
    }
    inline = [
      "echo '=== Starting Create Master List on redis0 node... ==='",
      "sleep 10",
      "echo -n '${data.oci_core_vnic.redis_master_vnic[count.index].private_ip_address}:6379 ' >> /home/opc/master_list.sh",
      "echo '=== Started Create Master List on redis0 node... ==='"
    ]
  }
}

resource "null_resource" "redis_replica_replica_list" {
  depends_on = [null_resource.redis_master_master_list]
  count      = var.redis_replica_count * var.redis_master_count
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_master_vnic[0].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      script_path = "/home/opc/myssh${count.index}.sh"
      agent       = false
      timeout     = "10m"
    }
    inline = [
      "echo '=== Starting Create Replica List on redis0 node... ==='",
      "sleep 10",
      "echo -n '${data.oci_core_vnic.redis_replica_vnic[count.index].private_ip_address}:6379 ' >> /home/opc/replica_list.sh",
      "echo '=== Started Create Replica List on redis0 node... ==='"
    ]
  }
}

resource "null_resource" "redis_master_create_cluster" {
  depends_on = [null_resource.redis_replica_replica_list]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "opc"
      host        = data.oci_core_vnic.redis_master_vnic[0].public_ip_address
      private_key = tls_private_key.public_private_key_pair.private_key_pem
      script_path = "/home/opc/myssh.sh"
      agent       = false
      timeout     = "10m"
    }
    inline = [
      "echo '=== Create REDIS CLUSTER from redis0 node... ==='",
      "sudo -u root /usr/local/bin/redis-cli --cluster create `cat /home/opc/master_list.sh` `cat /home/opc/replica_list.sh` -a ${random_string.redis_password.result} --cluster-replicas ${var.redis_replica_count} --cluster-yes",
      "echo '=== Cluster REDIS created from redis0 node... ==='",
      "echo 'cluster info' | /usr/local/bin/redis-cli -c -a ${random_string.redis_password.result}",
      "echo 'cluster nodes' | /usr/local/bin/redis-cli -c -a ${random_string.redis_password.result}"
    ]
  }
}

#resource "null_resource" "redis_master_start_sentinel" {
#  count      = var.redis_master_count
#  depends_on = [null_resource.redis_master_create_cluster]
#  provisioner "remote-exec" {
#    connection {
#      type        = "ssh"
#      user        = "opc"
#      host        = data.oci_core_vnic.redis_master_vnic[count.index].public_ip_address
#      private_key = tls_private_key.public_private_key_pair.private_key_pem
#      script_path = "/home/opc/myssh.sh"
#      agent       = false
#      timeout     = "10m"
#    }
#    inline = [
#      "echo '=== Starting REDIS SENTINEL on redis${count.index} node... ==='",
#      "sudo -u root nohup /usr/local/bin/redis-sentinel /etc/sentinel.conf > /tmp/redis-sentinel.log &",
#      "ps -ef | grep redis",
#      "sleep 10",
#      "sudo cat /tmp/redis-sentinel.log",
#      "echo '=== Started REDIS SENTINEL on redis${count.index} node... ==='"
#    ]
#  }
#}

#resource "null_resource" "redis_master_show_cluster_status" {
#  depends_on = [null_resource.redis_master_create_cluster]
#  provisioner "remote-exec" {
#    connection {
#      type        = "ssh"
#      user        = "opc"
#      host        = data.oci_core_vnic.redis_master_vnic[0].public_ip_address
#      private_key = tls_private_key.public_private_key_pair.private_key_pem
#      script_path = "/home/opc/myssh.sh"
#      agent       = false
#      timeout     = "10m"
#    }
#    inline = [
#      "echo '=== Show REDIS CLUSTER after runing Sentinel from redis0 node... ==='",
#      "echo 'cluster info' | /usr/local/bin/redis-cli -c -a ${random_string.redis_password.result}",
#      "echo 'cluster nodes' | /usr/local/bin/redis-cli -c -a ${random_string.redis_password.result}"
#    ]
#  }
#}

