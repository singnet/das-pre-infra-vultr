module "mongodb_cluster_shard" {
  source          = "../instance"
  create_resource = true
  count           = var.shard.nodes_per_cluster * var.shard.clusters
  name            = "shard${count.index % var.shard.nodes_per_cluster == 0 ? var.shard.nodes_per_cluster : count.index % var.shard.nodes_per_cluster}node${count.index}-${random_string.random[count.index].id}"
  environment     = var.environment
  user_data_file  = file("mongodb-shards/user-data/config-shard.sh")
  ssh_key_ids     = [vultr_ssh_key.mongodb_ssh_key.id]
  region          = var.region
  plan            = var.shard.instance_type

  depends_on = [
    module.mongodb_cluster_config_set,
    null_resource.mongo_init_config_set
  ]
}

resource "null_resource" "mongo_init_shard" {
  depends_on = [
    module.mongodb_cluster_shard
  ]

  count = var.shard.clusters
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
      host        = slice(module.mongodb_cluster_shard[*].instance_ip, count.index * var.shard.nodes_per_cluster, (count.index + 1) * var.shard.nodes_per_cluster)[0]
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap-cluster.sh", var.shard.clusters,
      "/tmp/bootstrap-cluster.sh ${join(" ",
      slice(module.mongodb_cluster_shard[*].instance_ip, count.index * var.shard.nodes_per_cluster, (count.index + 1) * var.shard.nodes_per_cluster))}"
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(local_file.mongodb_private_key.filename)
      host        = slice(module.mongodb_cluster_shard[*].instance_ip, count.index * var.shard.nodes_per_cluster, (count.index + 1) * var.shard.nodes_per_cluster)[0]
    }
  }
}
