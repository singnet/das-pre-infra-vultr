module "mongodb_cluster_shard" {
  source          = "../instance"
  create_resource = true
  count           = var.nodes_per_shard * var.shards
  name            = "shard${count.index % var.nodes_per_shard == 0 ? var.nodes_per_shard : count.index % var.nodes_per_shard}node${count.index}-${random_string.random[count.index].id}"
  environment     = var.environment
  user_data_file  = file("mongodb-shards/user-data/config-shard.sh")
  ssh_key_ids     = [vultr_ssh_key.mongodb_ssh_key.id]
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
      private_key = file(local_file.mongodb_private_key.filename)
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
      private_key = file(local_file.mongodb_private_key.filename)
      host        = slice(module.mongodb_cluster_shard[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set)[0]
    }
  }
}
