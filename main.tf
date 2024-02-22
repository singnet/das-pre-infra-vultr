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

  redis_params = {
    stack_version = "7.2.0-v8"
    port          = 29100
  }

  mongo_params = {
    version = "7.0.5"
    port    = 28100
  }

  os_params = {
    user_name = "dasadmin"
  }

}

data "template_file" "install_openfaas" {
  template = file("install-openfaas.sh")

  vars = {
    USER_NAME = local.os_params.user_name
  }
}

module "openfaas_instance" {
  source          = "./instance"
  create_resource = true
  name            = var.is_production ? "biodas1-openfaas" : "test-openfaas"
  environment     = local.environment
  user_data_file  = data.template_file.install_openfaas.rendered
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = local.openfaas_instance_plan
}

data "template_file" "install_redis" {
  template = file("install-redis.sh")

  vars = {
    USER_NAME            = local.os_params.user_name
    REDIS_STACK_VERSION  = local.redis_params.stack_version,
    REDIS_PORT           = local.redis_params.port,
    OPENFAAS_INSTANCE_ID = module.openfaas_instance.instance_ip
  }
}

module "redis_instance" {
  source          = "./instance"
  create_resource = true
  name            = var.is_production ? "biodas1-redis" : "test-redis"
  environment     = local.environment
  user_data_file  = data.template_file.install_redis.rendered
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = local.redis_instance_plan
}

data "template_file" "install_mongodb" {
  template = file("install-mongodb.sh")

  vars = {
    USER_NAME            = local.os_params.user_name
    MONGO_VERSION        = local.mongo_params.version,
    MONGO_PORT           = local.mongo_params.port,
    OPENFAAS_INSTANCE_ID = module.openfaas_instance.instance_ip
  }
}

module "mongodb_instance" {
  source          = "./instance"
  create_resource = true
  name            = var.is_production ? "biodas1-mongodb" : "test-mongodb"
  environment     = local.environment
  user_data_file  = data.template_file.install_mongodb.rendered
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
