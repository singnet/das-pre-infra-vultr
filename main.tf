terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.15.1"
    }
  }
}

variable "is_production" {
  type    = bool
  default = false
}

variable "ssh_key_ids" {
  type = list(string)
}

variable "region" {
  type = string
}

variable "production_instances_plan" {
  type = string
}

variable "test_instances_plan" {
  type = string
}

locals {
  environment            = var.is_production ? "prod" : "test"
  openfaas_instance_plan = var.is_production ? var.production_instances_plan : var.test_instances_plan
  redis_instance_plan    = var.is_production ? var.production_instances_plan : var.test_instances_plan
  mongodb_instance_plan  = var.is_production ? var.production_instances_plan : var.test_instances_plan
}

module "openfaas_instance" {
  source          = "./instance"
  create_resource = 1
  name            = var.is_production ? "openfaas" : "test-openfaas"
  environment     = local.environment
  user_data_file  = "install-openfaas.sh"
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = local.openfaas_instance_plan
}

module "redis_instance" {
  source          = "./instance"
  create_resource = 3
  name            = var.is_production ? "redis" : "test-redis"
  environment     = local.environment
  user_data_file  = "install-redis.sh"
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = local.redis_instance_plan
}

module "mongodb_instance" {
  source          = "./instance"
  create_resource = 1
  name            = var.is_production ? "mongodb" : "test-mongodb"
  environment     = local.environment
  user_data_file  = "install-mongodb.sh"
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = local.mongodb_instance_plan
}

output "openfaas_instance_ip" {
  value = module.openfaas_instance.instance_ip
}

output "redis_instance_ip" {
  value = module.redis_instance.instance_ip
}

output "mongodb_instance_ip" {
  value = module.mongodb_instance.instance_ip
}
