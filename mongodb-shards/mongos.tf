module "mongodb_cluster_mongos" {
  source          = "../instance"
  create_resource = true
  count           = var.mongos
  name            = "mongos${count.index}-${random_string.random[count.index].id}"
  environment     = var.environment
  user_data_file  = file("mongodb-shards/user-data/config-mongos.sh")
  ssh_key_ids     = [vultr_ssh_key.mongodb_ssh_key.id]
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
      private_key = file(local_file.mongodb_private_key.filename)
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
      private_key = file(local_file.mongodb_private_key.filename)
      host        = module.mongodb_cluster_mongos[count.index].instance_ip
    }
  }
}
