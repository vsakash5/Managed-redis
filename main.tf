#==============================================================================
# AZURE REDIS CACHE WITH GEO-REPLICATION EXAMPLE
# This configuration demonstrates how to set up Azure Redis Cache instances
# with geo-replication across multiple regions for high availability
#==============================================================================

#--------------------------------
# Local Variables and Logic
#--------------------------------
locals {
  # Check if all required replica inputs are provided
  replica_inputs_ready = alltrue([
    var.environment_replica != null,
    var.location_replica != null,
    var.resource_group_name_replica != null,
    var.context_prefix_replica != null
  ])
 
  # Enable replica deployment only if config exists and inputs are ready
  replica_enabled = length(var.managed_redis_config_replica) > 0 && local.replica_inputs_ready
}

#--------------------------------
# User Assigned Identity for Primary Redis Instances
# Required for customer-managed key encryption
#--------------------------------
resource "azurerm_user_assigned_identity" "redis_primary" {
  for_each = var.managed_redis_config

  name                = "uai-redis-${each.value.context_suffix}-${each.value.instance}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = var.tags
}
 
#--------------------------------
# User Assigned Identity for Replica Redis Instances
# Required for customer-managed key encryption in replica region
#--------------------------------
resource "azurerm_user_assigned_identity" "redis_replica" {
  for_each = local.replica_enabled ? var.managed_redis_config_replica : {}
 
  name                = "uai-redis-replica-${each.value.context_suffix}-${each.value.instance}"
  location            = var.location_replica
  resource_group_name = var.resource_group_name_replica
  tags                = var.tags
}
 
#--------------------------------
# Primary Redis Cache Instances
# Enterprise-grade Redis with customer-managed encryption
#--------------------------------
resource "azurerm_redis_enterprise_cache" "primary" {
  for_each            = var.managed_redis_config
  
  name                = "redis-${var.context_prefix}-${each.value.context_suffix}-${each.value.instance}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location
  sku_name            = each.value.sku_name

  # Security: Disable public network access
  public_network_access_enabled = false
  
  # High availability configuration
  zones = each.value.high_availability_enabled ? data.azurerm_availability_zones.available.names : null

  # Customer-managed encryption key
  customer_managed_key_encryption_key_url = data.azurerm_key_vault_key.redis_key[each.value.kv_key].id
  
  # Managed identity for key vault access
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.redis_primary[each.key].id]
  }

  tags = var.tags
}
 
#----------------------------------------------
# Private Endpoints for Primary Redis Instances
# Ensures secure, private network connectivity
#----------------------------------------------
resource "azurerm_private_endpoint" "redis_primary" {
  for_each            = var.managed_redis_pe_config
  
  name                = "pe-redis-${each.value.context}-${each.value.instance}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id          = data.azurerm_subnet.snet[each.value.snet_key].id

  private_service_connection {
    name                           = "psc-redis-${each.value.context}-${each.value.instance}"
    private_connection_resource_id = azurerm_redis_enterprise_cache.primary[each.value.managed_redis_key].id
    subresource_names             = each.value.group_ids
    is_manual_connection          = each.value.is_manual_connection
    
    # Optional: Use static IP if required
    private_ip_address = each.value.static_ip_required ? each.value.static_ip_address : null
  }

  # DNS integration for private endpoint
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.redis.id]
  }

  tags = var.tags
  
  depends_on = [azurerm_redis_enterprise_cache.primary]
}
 
 
#----------------------------------------------
# Private Endpoints for Replica Redis Instances
# Ensures secure connectivity in the replica region
#----------------------------------------------
resource "azurerm_private_endpoint" "redis_replica" {
  for_each            = local.replica_enabled ? var.managed_redis_pe_config_replica : {}
  
  name                = "pe-redis-replica-${each.value.context}-${each.value.instance}"
  location            = var.location_replica
  resource_group_name = var.resource_group_name_replica
  subnet_id          = data.azurerm_subnet.snet[each.value.snet_key_replica].id

  private_service_connection {
    name                           = "psc-redis-replica-${each.value.context}-${each.value.instance}"
    private_connection_resource_id = azurerm_redis_enterprise_cache.replica[each.value.managed_redis_key_replica].id
    subresource_names             = each.value.group_ids
    is_manual_connection          = each.value.is_manual_connection
    
    # Optional: Use static IP if required
    private_ip_address = each.value.static_ip_required ? each.value.static_ip_address : null
  }

  # DNS integration for private endpoint
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.redis_replica.id]
  }

  tags = var.tags
  
  depends_on = [azurerm_redis_enterprise_cache.replica]
}
 
#--------------------------------
# Replica Redis Cache Instances
# Secondary region instances for geo-replication
#--------------------------------
resource "azurerm_redis_enterprise_cache" "replica" {
  for_each            = local.replica_enabled ? var.managed_redis_config_replica : {}
  
  name                = "redis-replica-${var.context_prefix_replica}-${each.value.context_suffix}-${each.value.instance}"
  resource_group_name = var.resource_group_name_replica
  location            = var.location_replica
  sku_name            = each.value.sku_name

  # Security: Disable public network access
  public_network_access_enabled = false
  
  # High availability configuration
  zones = each.value.high_availability_enabled ? data.azurerm_availability_zones.available_replica.names : null

  # Customer-managed encryption key (from replica region key vault)
  customer_managed_key_encryption_key_url = data.azurerm_key_vault_key.redis_key[each.value.kv_key_replica].id
  
  # Managed identity for key vault access
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.redis_replica[each.key].id]
  }

  tags = var.tags
}
 
#--------------------------------------
# Redis Enterprise Geo-Replication
# Links primary and replica instances for automatic failover
#--------------------------------------
resource "azurerm_redis_enterprise_database" "geo_replication" {
  for_each = local.replica_enabled ? var.managed_redis_geo_replication_config : {}

  # Database configuration on primary cache
  cluster_id = azurerm_redis_enterprise_cache.primary[each.value.primary_redis_key].id
  name       = "default"
  
  # Clustering and eviction policies
  clustering_policy = var.managed_redis_config[each.value.primary_redis_key].default_database.clustering_policy
  eviction_policy   = var.managed_redis_config[each.value.primary_redis_key].default_database.eviction_policy
  
  # Geo-replication configuration
  linked_database_id = [
    for replica_key in each.value.replica_keys :
    "${azurerm_redis_enterprise_cache.replica[replica_key].id}/databases/default"
  ]
  
  # Geo-replication group name for linking instances
  linked_database_group_nickname = var.managed_redis_config[each.value.primary_redis_key].default_database.geo_replication_group_name

  depends_on = [
    azurerm_redis_enterprise_cache.primary,
    azurerm_redis_enterprise_cache.replica
  ]
}
