variable "ssh_key_ids" {
  type = list(string)
}

variable "region" {
  type = string
}

variable "environment" {
  type    = string 
}


resource "random_string" "random" {
  length           = 16
  special          = true
  override_special = "/@£$"
}

module "mongodb_cluster_config_set" {
  source          = "../instance"
  create_resource = true
  count           = 2
  name            = "configrepl${count.index}-${random_string.random[count.index].id}"
  environment     = var.environment
  user_data_file  = file("user-data/mongodb-cluster/config-set.sh")
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = "vc2-1c-2gb"
}

resource "null_resource" "mongo_init_replica_set" {
  depends_on = [
    module.mongodb_cluster_config_set
  ]

  triggers = {
    cluster_instance_ids = join(",", module.mongodb_cluster_config_set[*].instance_ip)
  }

  provisioner "remote-exec" {
    inline = [
      "/tmp/bootstrap-cluster.sh ${join(" ",
      module.mongodb_cluster_config_set[*].instance_ip)}",
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/openfaas.pem")
      host        = module.mongodb_cluster_config_set[0].instance_ip
    }
  }
}
