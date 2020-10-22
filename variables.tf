variable "mnemon_location" {
  type = string
}

variable "mnemon_domain" {
  type = string
}

variable "mnemon_resource_prefix" {
  type = string
}

variable "mnemon_os_username" {
  type = string
}

variable "mnemon_web_username" {
  type = string
}

variable "mnemon_vnet_address_space" {
  type = string
}

variable "mnemon_subnet_address_prefix" {
  type = string
}

variable "secrets_resource_group" {
  type = string
}

variable "security_inbound_allow_rules" {
  type = list(map(string))
}
