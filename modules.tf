#==============================================================================
# DATA SOURCES AND SHARED RESOURCES
# This file contains shared data sources and common resources used by
# the Redis cache deployment
#==============================================================================

#--------------------------------------------------
# Data Sources - Existing Azure Resources
#--------------------------------------------------

# Get reference to existing resource group
data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

# Get available availability zones for primary region
data "azurerm_availability_zones" "available" {
  location = var.location
}

# Get available availability zones for replica region (if enabled)
data "azurerm_availability_zones" "available_replica" {
  count    = local.replica_enabled ? 1 : 0
  location = var.location_replica
}

# Data source for virtual networks used by subnets
data "azurerm_virtual_network" "vnet" {
  for_each            = var.vnet_datasource_config
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}

# Data source for subnets used by private endpoints
data "azurerm_subnet" "snet" {
  for_each             = var.snet_datasource_config
  name                 = each.value.name
  virtual_network_name = each.value.virtual_network_name
  resource_group_name  = each.value.resource_group_name
}

# Data source for key vaults containing encryption keys
data "azurerm_key_vault" "keyvault" {
  for_each            = var.kv_datasource_config
  name                = each.value.keyvault_name
  resource_group_name = each.value.keyvault_resource_group_name
}

# Data source for encryption keys in key vaults
data "azurerm_key_vault_key" "redis_key" {
  for_each     = var.kv_datasource_config
  name         = "redis-encryption-key"  # Generic key name
  key_vault_id = data.azurerm_key_vault.keyvault[each.key].id
}

# Private DNS zones for Redis private endpoints
data "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redisenterprise.cache.azure.net"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "redis_replica" {
  count               = local.replica_enabled ? 1 : 0
  name                = "privatelink.redisenterprise.cache.azure.net"
  resource_group_name = var.resource_group_name_replica
}

#--------------------------------------------------
# Role Assignments for Customer-Managed Keys
#--------------------------------------------------

# Assign Key Vault Crypto Service Encryption User role to primary Redis identities
resource "azurerm_role_assignment" "redis_cmk_primary" {
  for_each             = var.managed_redis_config
  scope                = data.azurerm_key_vault.keyvault[each.value.kv_key].id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.redis_primary[each.key].principal_id
  description          = "Allow Redis primary instance to access encryption keys"
}

# Assign Key Vault Crypto Service Encryption User role to replica Redis identities
resource "azurerm_role_assignment" "redis_cmk_replica" {
  for_each             = local.replica_enabled ? var.managed_redis_config_replica : {}
  scope                = data.azurerm_key_vault.keyvault[each.value.kv_key_replica].id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.redis_replica[each.key].principal_id
  description          = "Allow Redis replica instance to access encryption keys"
}

#--------------------------------------------------
# Local Variables
#--------------------------------------------------
locals {
  # Common tags for all resources
  common_tags = merge(var.tags, {
    "Environment"   = var.environment
    "ManagedBy"     = "Terraform"
    "DeployedAt"    = timestamp()
  })
}