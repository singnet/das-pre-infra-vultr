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

  provisioner "remote-exec" {
    inline = [
      <<-EOF
        members = []
        for i in range(${length(module.mongodb_cluster_config_set)}) {
          members.append("{_id: ${i}, host: \\"${module.mongodb_cluster_config_set[i].public_ip}:2804${i+1}\\"}")
        }
        rsconf = "{_id: \\"config_repl\\", members: [${join(",", members)}]}"
        echo "Configuração do replica set: ${rsconf}"
        mongosh --host ${module.mongodb_cluster_config_set[0].public_ip} --port 28041 --eval "rs.initiate(${rsconf})"
      EOF
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/openfaas.pem")
      host        = module.mongodb_cluster_config_set[0].public_ip
    }
  }
}