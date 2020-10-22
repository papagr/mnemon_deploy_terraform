data "azurerm_key_vault" "mnemon_kv" {
  name                = "mnemon-vault"
  resource_group_name = var.secrets_resource_group
}

data "azurerm_key_vault_secret" "web_password" {
  name         = "web-password"
  key_vault_id = data.azurerm_key_vault.mnemon_kv.id
}

data "azurerm_key_vault_secret" "os_password" {
  name         = "os-password"
  key_vault_id = data.azurerm_key_vault.mnemon_kv.id
}

data "azurerm_key_vault_certificate" "web_ssl" {
  name         = "mnemon-eu"
  key_vault_id = data.azurerm_key_vault.mnemon_kv.id
}