terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.15.1"
    }
  }
}

variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "user_data_file" {
  type = string
}

variable "ssh_key_ids" {
  type = list(string)
}

variable "region" {
  type = string
}

variable "plan" {
  type = string
}

variable "create_resource" {
  type    = number
  default = 0
}

locals {
  is_bare_metal = startswith(var.plan, "vbm")
}

resource "vultr_bare_metal_server" "bare_metal" {
  count    = local.is_bare_metal ? var.create_resource : 0
  label    = var.name
  hostname = var.name
  plan     = var.plan
  region   = var.region
  os_id    = 1743
  tags = [
    join(": ", ["env", var.environment]),
    join(": ", ["plan", var.plan]),
    join(": ", ["region", var.region]),
    join(": ", ["os", "1743"]),
  ]
  user_data        = file(var.user_data_file)
  ssh_key_ids      = var.ssh_key_ids
  enable_ipv6      = true
  activation_email = true
}

resource "vultr_instance" "regular" {
  count    = !local.is_bare_metal ? var.create_resource : 0
  label    = var.name
  hostname = var.name
  plan     = var.plan
  region   = var.region
  os_id    = 1743
  tags = [
    join(": ", ["env", var.environment]),
    join(": ", ["plan", var.plan]),
    join(": ", ["region", var.region]),
    join(": ", ["os", "1743"]),
  ]
  user_data        = file(var.user_data_file)
  ssh_key_ids      = var.ssh_key_ids
  enable_ipv6      = false
  activation_email = false
}

output "instance_ip" {
  value = var.create_resource > 0 ? (local.is_bare_metal ? vultr_bare_metal_server.bare_metal[0].main_ip : vultr_instance.regular[0].main_ip) : ""
}
