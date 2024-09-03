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
  length  = 16
  special = false
  count   = var.nodes_per_config_set * var.config_set_count
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

resource "null_resource" "mongo_init_config_set" {
  depends_on = [
    module.mongodb_cluster_config_set
  ]

  count = var.config_set_count
  triggers = {
    cluster_instance_ids = join(",", module.mongodb_cluster_config_set[*].instance_ip)
  }

  provisioner "file" {
    source      = "mongodb-shards/user-data/init-config-set.sh"
    destination = "/tmp/bootstrap-cluster.sh"


    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/server.pem")
      host        = slice(module.mongodb_cluster_config_set[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set)[0]
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap-cluster.sh",
      "/tmp/bootstrap-cluster.sh ${join(" ",
      slice(module.mongodb_cluster_config_set[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set))}"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/server.pem")
      host        = slice(module.mongodb_cluster_config_set[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set)[0]
    }
  }
}


module "mongodb_cluster_shard" {
  source          = "../instance"
  create_resource = true
  count           = var.nodes_per_shard * var.shards
  name            = "shard${count.index % var.nodes_per_shard == 0 ? var.nodes_per_shard : count.index % var.nodes_per_shard}node${count.index}-${random_string.random[count.index].id}"
  environment     = var.environment
  user_data_file  = file("mongodb-shards/user-data/config-shard.sh")
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = "vc2-1c-2gb"
}

resource "null_resource" "mongo_init_shard" {
  depends_on = [
    module.mongodb_cluster_shard
  ]

  count = var.config_set_count
  triggers = {
    cluster_instance_ids = join(",", module.mongodb_cluster_shard[*].instance_ip)
  }

  provisioner "file" {
    source      = "mongodb-shards/user-data/init-shard-set.sh"
    destination = "/tmp/bootstrap-cluster.sh"


    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/server.pem")
      host        = slice(module.mongodb_cluster_shard[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set)[0]
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap-cluster.sh", var.mongos,
      "/tmp/bootstrap-cluster.sh ${join(" ",
      slice(module.mongodb_cluster_shard[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set))}"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/server.pem")
      host        = slice(module.mongodb_cluster_shard[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set)[0]
    }
  }
}



module "mongodb_cluster_mongos" {
  source          = "../instance"
  create_resource = true
  count           = var.mongos
  name            = "mongos${count.index}-${random_string.random[count.index].id}"
  environment     = var.environment
  user_data_file  = file("mongodb-shards/user-data/config-mongos.sh")
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = "vc2-1c-2gb"
}


resource "null_resource" "mongo_init_mongos" {
  depends_on = [
    module.mongodb_cluster_mongos
  ]

  count = var.mongos
  triggers = {
    cluster_instance_ids = join(",", module.mongodb_cluster_mongos[*].instance_ip)
  }

  provisioner "file" {
    source      = "mongodb-shards/user-data/init-mongos.sh"
    destination = "/tmp/bootstrap-cluster.sh"


    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/server.pem")
      host        = module.mongodb_cluster_mongos[count.index].instance_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap-cluster.sh",
      "/tmp/bootstrap-cluster.sh --config-set ${join(",", module.mongodb_cluster_config_set[*].instance_ip)} --shards ${join(",", module.mongodb_cluster_shard[*].instance_ip)}"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/server.pem")
      host        = module.mongodb_cluster_mongos[count.index].instance_ip
    }
  }
}
