module "mongodb_cluster_config_set" {
  source          = "../instance"
  create_resource = true
  count           = var.nodes_per_config_set * var.config_set_count
  name            = "configrepl${count.index}-${random_string.random[count.index].id}"
  environment     = var.environment
  user_data_file  = file("mongodb-shards/user-data/config-set.sh")
  ssh_key_ids     = [vultr_ssh_key.mongodb_ssh_key.id]
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
      private_key = file(local_file.mongodb_private_key.filename)
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
      private_key = file(local_file.mongodb_private_key.filename)
      host        = slice(module.mongodb_cluster_config_set[*].instance_ip, count.index * var.nodes_per_config_set, (count.index + 1) * var.nodes_per_config_set)[0]
    }
  }
}
