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
data "template_file" "mongodb_user_data" {
  template = file("install-server.sh")

  vars = merge(local.instance_user_data, {
    environment_type = "toolbox"
    redis_nodes      = join(" ", [])
    redis_node_len   = 0
  })
}

module "mongodb_instance" {
  source          = "./instance"
  create_resource = false
  name            = "biodas1-mongodb"
  environment     = local.environment
  user_data_file  = data.template_file.mongodb_user_data.rendered
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

module "das_github_runner" {
  source          = "./instance"
  create_resource = true
  name            = "das-github-runner"
  environment     = local.environment
  user_data_file  = file("github-runner.sh")
  ssh_key_ids     = []
  region          = var.region
  plan            = "vc2-6c-16gb"
}


data "template_file" "nunet_integration_test_data" {
  template = file("install-server.sh")

  vars = merge(local.instance_user_data, {
    environment_type = "toolbox"
    redis_nodes      = join(" ", [])
    redis_node_len   = 0
  })
}


module "nunet_integration_test" {
  source          = "./instance"
  create_resource = true
  name            = "nunet-integration-test"
  environment     = local.environment
  user_data_file  = data.template_file.nunet_integration_test_data.rendered
  ssh_key_ids     = var.ssh_key_ids
  region          = var.region
  plan            = "voc-g-2c-8gb-50s"
}
