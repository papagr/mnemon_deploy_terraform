output "mnemon_public_ip" {
  value = azurerm_public_ip.mnemon_extip.ip_address
}

output "mnemon_ssh_pkey" {
  value = tls_private_key.mnemon_ssh.private_key_pem
}