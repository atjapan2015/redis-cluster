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
      "sudo chmod 777 /etc/redis.conf",
      "if [[ `hostname -s` != '${data.oci_core_vnic.redis_master_vnic[0].hostname_label}' ]]; then echo 'slaveof ${data.oci_core_vnic.redis_master_vnic[0].private_ip_address} 6379' >> /etc/redis.conf; fi",
      "sudo chmod 644 /etc/redis.conf",
      "sudo systemctl start redis.service",
      "sleep 5",
      "sudo systemctl status redis.service",
      "echo '=== Started REDIS on redis${count.index} node... ==='"
    ]
  }
}

resource "null_resource" "redis_replica_start_redis" {
  depends_on = [null_resource.redis_master_start_redis]
  count      = var.redis_replica_count  * (var.is_redis_cluster ? var.redis_master_count : 0)
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
      "sudo systemctl start redis.service",
      "sleep 5",
      "sudo systemctl status redis.service",
      "echo '=== Started REDIS on redis${count.index + var.redis_master_count} node... ==='"
    ]
  }
}

resource "null_resource" "redis_master_master_list" {
  depends_on = [null_resource.redis_replica_start_redis]
  count      = var.is_redis_cluster ? var.redis_master_count : 0
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
      "echo -n '${data.oci_core_vnic.redis_master_vnic[count.index].public_ip_address}:6379 ' >> /home/opc/master_list.sh",
      "echo '=== Started Create Master List on redis0 node... ==='"
    ]
  }
}

resource "null_resource" "redis_replica_replica_list" {
  depends_on = [null_resource.redis_master_master_list]
  count      = var.redis_replica_count * (var.is_redis_cluster ? var.redis_master_count : 0)
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
      "echo -n '${data.oci_core_vnic.redis_replica_vnic[count.index].public_ip_address}:6379 ' >> /home/opc/replica_list.sh",
      "echo '=== Started Create Replica List on redis0 node... ==='"
    ]
  }
}

resource "null_resource" "redis_master_create_cluster" {
  depends_on = [null_resource.redis_replica_replica_list]
  count      = var.is_redis_cluster ? 1 : 0
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
      "echo 'cluster nodes' | /usr/local/bin/redis-cli -c -a ${random_string.redis_password.result}",
    ]
  }
}

resource "null_resource" "redis_master_start_sentinel" {
  depends_on = [null_resource.redis_master_start_redis]
  count      = var.is_redis_cluster ? 0 : var.redis_master_count
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
      "echo '=== Starting REDIS SENTINEL on redis${count.index} node... ==='",
      "sudo systemctl enable redis-sentinel.service",
      "sudo systemctl start redis-sentinel.service",
      "sleep 5",
      "sudo systemctl status redis-sentinel.service",
      "echo '=== Started REDIS SENTINEL on redis${count.index} node... ==='"
    ]
  }
}

resource "null_resource" "redis_master_register_grafana" {
  depends_on = [null_resource.redis_master_create_cluster]
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
      "echo '=== Register REDIS Datasource to Grafana... ==='",
      "curl -d '{\"name\":\"Redis\",\"type\":\"redis-datasource\",\"typeName\":\"Redis\",\"typeLogoUrl\":\"public/plugins/redis-datasource/img/logo.svg\",\"access\":\"proxy\",\"url\":\"redis://${data.oci_core_vnic.redis_master_vnic[0].private_ip_address}:6379\",\"password\":\"\",\"user\":\"\",\"database\":\"\",\"basicAuth\":false,\"isDefault\":false,\"jsonData\":{\"client\":\"cluster\"},\"secureJsonData\":{\"password\":\"${random_string.redis_password.result}\"},\"readOnly\":false}' -H \"Content-Type: application/json\" -X POST http://admin:${var.global_password}@redismanager:3000/api/datasources"
    ]
  }
}