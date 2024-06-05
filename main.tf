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
  environment                      = var.is_production ? "prod" : "test"
  openfaas_instance_plan           = var.is_production ? var.production_instances_plan : var.test_instances_plan
  redis_instance_plan              = var.is_production ? var.production_instances_plan : var.test_instances_plan
  mongodb_instance_plan            = var.is_production ? var.production_instances_plan : var.test_instances_plan
  das_apt_repository_instance_plan = var.test_instances_plan

  instance_user_data = {
    redis_stack_version = "7.2.0-v8"
    redis_port          = 29100
    mongo_version       = "7.0.5"
    mongo_port          = 28100
    user_name           = "dasadmin"
  }
}

data "template_file" "install_openfaas" {
  template = file("install-server.sh")

  vars = merge(local.instance_user_data, {
    environment_type = "openfaas"
  })
}

module "openfaas_instance" {
  source          = "./instance"
  create_resource = false
  name            = var.is_production ? "biodas1-openfaas" : "test-openfaas"
  environment     = local.environment
  user_data_file  = data.template_file.install_openfaas.rendered
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = local.openfaas_instance_plan
}

data "template_file" "install_redis" {
  template = file("install-server.sh")

  vars = merge(local.instance_user_data, {
    environment_type     = "redis"
    openfaas_instance_ip = module.openfaas_instance.instance_ip
  })
}

module "redis_instance" {
  source          = "./instance"
  create_resource = true
  name            = "biodas1-redis"
  environment     = local.environment
  user_data_file  = data.template_file.install_redis.rendered
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = local.redis_instance_plan
}

data "template_file" "install_mongodb" {
  template = file("install-server.sh")

  vars = merge(local.instance_user_data, {
    environment_type     = "redis"
    openfaas_instance_ip = module.openfaas_instance.instance_ip
  })
}

module "mongodb_instance" {
  source          = "./instance"
  create_resource = false
  name            = "biodas1-mongodb"
  environment     = local.environment
  user_data_file  = data.template_file.install_mongodb.rendered
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = local.mongodb_instance_plan
}

module "das_apt_repository" {
  source          = "./instance"
  create_resource = true
  name            = "das-apt-repository"
  environment     = local.environment
  user_data_file  = file("install-apt-repository.sh")
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = "vc2-1c-2gb"
}

data "template_file" "install_toolbox" {
  template = file("install-server.sh")

  vars = merge(local.instance_user_data, {
    environment_type = "toolbox"
  })
}

module "test_cluster_redis_instance" {
  source          = "./instance"
  create_resource = false
  count           = 3
  name            = "server${count.index}-redis"
  environment     = local.environment
  user_data_file  = data.template_file.install_toolbox.rendered
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
