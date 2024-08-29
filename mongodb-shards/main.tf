variable "ssh_key_ids" {
  type = list(string)
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "shards" {
  type = number
}

variable "nodes_per_shard" {
  type = number
}


variable "config_set_count" {
  type = number
}


variable "nodes_per_config_set" {
  type = number
}


variable "mongos" {
  type = number
}


resource "random_string" "random" {
  length           = 16
  special          = true
  override_special = "/@£$"
  count            = var.nodes_per_config_set * var.config_set_count
}

module "mongodb_cluster_config_set" {
  source          = "../instance"
  create_resource = true
  count           = var.nodes_per_config_set * var.config_set_count
  name            = "configrepl${count.index}-${random_string.random[count.index].id}"
  environment     = var.environment
  user_data_file  = file("mongodb-shards/user-data/config-set.sh")
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = "vc2-1c-2gb"
}

resource "null_resource" "mongo_init_replica_set" {
  depends_on = [
    module.mongodb_cluster_config_set
  ]

  count = var.config_set_count
  triggers = {
    cluster_instance_ids = join(",", module.mongodb_cluster_config_set[*].instance_ip)
  }

  provisioner "file" {
    source      = "./user-data/init-replica-set.sh"
    destination = "/tmp/bootstrap-cluster.sh"


    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/server.pem")
      host        = slice(module.mongodb_cluster_config_set[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set)[0]
    }
  }

  provisioner "remote-exec" {
    inline = [
      "/tmp/bootstrap-cluster.sh ${join(" ",
      slice(module.mongodb_cluster_config_set[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set))}"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/server.pem")
      host        = slice(module.mongodb_cluster_config_set[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set)[0]
    }
  }
}
