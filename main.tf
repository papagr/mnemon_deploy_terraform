terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "mnemon_rg" {
  name     = "${var.mnemon_resource_prefix}-rg"
  location = var.mnemon_location
}

resource "azurerm_virtual_network" "mnemon_vnet" {
  name                = "${var.mnemon_resource_prefix}-vnet"
  location            = var.mnemon_location
  address_space       = [var.mnemon_vnet_address_space]
  resource_group_name = azurerm_resource_group.mnemon_rg.name
}

resource "azurerm_subnet" "mnemon_subnet" {
  name                 = "${var.mnemon_resource_prefix}-subnet"
  virtual_network_name = azurerm_virtual_network.mnemon_vnet.name
  resource_group_name  = azurerm_resource_group.mnemon_rg.name
  address_prefixes     = [var.mnemon_subnet_address_prefix]
}

resource "azurerm_public_ip" "mnemon_extip" {
  name                = "${var.mnemon_resource_prefix}-extip"
  location            = var.mnemon_location
  resource_group_name = azurerm_resource_group.mnemon_rg.name
  allocation_method   = "Static"
}

resource "azurerm_dns_zone" "mnemon_dns" {
  name                = var.mnemon_domain
  resource_group_name = azurerm_resource_group.mnemon_rg.name
}

resource "azurerm_dns_a_record" "mnemon_dns_a" {
  name                = "@"
  zone_name           = azurerm_dns_zone.mnemon_dns.name
  resource_group_name = azurerm_resource_group.mnemon_rg.name
  ttl                 = 3600
  records             = [azurerm_public_ip.mnemon_extip.ip_address]
}

resource "azurerm_dns_cname_record" "mnemon_dns_cname" {
  name                = "www"
  zone_name           = azurerm_dns_zone.mnemon_dns.name
  resource_group_name = azurerm_resource_group.mnemon_rg.name
  ttl                 = 3600
  record              = "${var.mnemon_domain}."
}

resource "azurerm_network_security_group" "mnemon_nsg" {
  name                = "${var.mnemon_resource_prefix}-nsg"
  location            = var.mnemon_location
  resource_group_name = azurerm_resource_group.mnemon_rg.name

  dynamic "security_rule" {
    for_each = var.security_inbound_allow_rules
    content  {
        name                       = security_rule.value.name
        priority                   = security_rule.value.priority
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = security_rule.value.protocol
        source_port_range          = "*"
        destination_port_range     = security_rule.value.destination_port_range
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
  }
}

resource "azurerm_network_interface" "mnemon_nic" {
  name                      = "${var.mnemon_resource_prefix}-nic"
  location                  = var.mnemon_location
  resource_group_name       = azurerm_resource_group.mnemon_rg.name

  ip_configuration {
    name                          = "${var.mnemon_resource_prefix}-ipcfg"
    subnet_id                     = azurerm_subnet.mnemon_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mnemon_extip.id
  }
}

resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.mnemon_nic.id
  network_security_group_id = azurerm_network_security_group.mnemon_nsg.id
}

resource "random_id" "rid" {
    keepers = {
        resource_group = azurerm_resource_group.mnemon_rg.name
    }
    byte_length = 8
}

resource "azurerm_storage_account" "mnemon_boot_diag" {
  name                     = "diag${random_id.rid.hex}"
  location                 = var.mnemon_location
  resource_group_name      = azurerm_resource_group.mnemon_rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "tls_private_key" "mnemon_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "azurerm_linux_virtual_machine" "mnemon_vm" {
  name                            = "${var.mnemon_resource_prefix}-vm"
  location                        = var.mnemon_location
  resource_group_name             = azurerm_resource_group.mnemon_rg.name
  size                            = "Standard_A2"
  admin_username                  = var.mnemon_os_username
  admin_password                  = data.azurerm_key_vault_secret.os_password.value
  computer_name                   = "${var.mnemon_resource_prefix}-ubuntu"
  network_interface_ids           = [azurerm_network_interface.mnemon_nic.id]
  disable_password_authentication = true

  os_disk {
    name                 = "${var.mnemon_resource_prefix}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference  {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.mnemon_os_username
    public_key = tls_private_key.mnemon_ssh.public_key_openssh
  }

  secret {
    key_vault_id = data.azurerm_key_vault.mnemon_kv.id
    certificate {
      url = data.azurerm_key_vault_certificate.web_ssl.secret_id
    }
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mnemon_boot_diag.primary_blob_endpoint
  }

  provisioner "file" {
    source      = "./ansible"
    destination = "/home/${var.mnemon_os_username}"

    connection {
      type = "ssh"
      host = var.mnemon_domain
      user = var.mnemon_os_username
      private_key = tls_private_key.mnemon_ssh.private_key_pem
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install software-properties-common --yes",
      "sudo apt-add-repository --yes --update ppa:ansible/ansible",
      "sudo apt install ansible --yes",
      "cd ~/ansible",
      "ansible-playbook -i localhost, mnemon.yml -e web_username=${var.mnemon_web_username} -e web_password=${data.azurerm_key_vault_secret.web_password.value}"
    ]

    connection {
      type = "ssh"
      host = var.mnemon_domain
      user = var.mnemon_os_username
      private_key = tls_private_key.mnemon_ssh.private_key_pem
    }
  }
}