variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "shard" {
  type = object({
    clusters          = number
    nodes_per_cluster = number
    instance_type     = string
  })
}


variable "config_set" {
  type = object({
    clusters          = number
    nodes_per_cluster = number
    instance_type     = string
  })
}

variable "mongos" {
  type = object({
    nodes         = number
    instance_type = string
  })
}

terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.15.1"
    }
  }
}

resource "random_string" "random" {
  length  = 16
  special = false
  count   = var.config_set.clusters * var.config_set.nodes_per_cluster
}

resource "tls_private_key" "mongodb_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "vultr_ssh_key" "mongodb_ssh_key" {
  name    = "mongodb-shard-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  ssh_key = tls_private_key.mongodb_ssh_key.public_key_openssh
}

resource "local_file" "mongodb_private_key" {
  content  = tls_private_key.mongodb_ssh_key.private_key_pem
  filename = "${vultr_ssh_key.mongodb_ssh_key.name}.pem"
}

