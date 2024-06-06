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
  instance_plan                    = var.is_production ? var.production_instances_plan : var.test_instances_plan
  das_apt_repository_instance_plan = var.test_instances_plan

  instance_user_data = {
    redis_stack_version = "7.2.0-v8"
    redis_port          = 29100
    mongo_version       = "7.0.5"
    mongo_port          = 28100
    user_name           = "dasadmin"
  }
}

module "mongodb_instance" {
  source          = "./instance"
  create_resource = false
  name            = "biodas1-mongodb"
  environment     = local.environment
  user_data_file  = data.template_file.install_mongodb.rendered
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = local.instance_plan
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
