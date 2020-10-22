terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "mnemonstorage"
    container_name       = "tfstate"
    key                  = "mnemon.tfstate"
  }
}
