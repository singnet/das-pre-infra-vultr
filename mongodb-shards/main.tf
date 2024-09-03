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

resource "tls_private_key" "mongodb_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "vultr_ssh_key" "mongodb_ssh_key" {
  name = "mongodb-shard-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  ssh_key = tls_private_key.ssh_key.public_key_pem
}

resource "local_file" "mongodb_private_key" {
  content = tls_private_key.mongodb_ssh_key.private_key_pem
  filename = "${vultr_ssh_key.mongodb_ssh_key.name}.pem"
}

