#==============================================================================
# TERRAFORM OUTPUTS
# This file defines output values that can be used by other configurations
# or for integration with external systems
#==============================================================================

#---------------------------------
# Primary Redis Instance Outputs
#---------------------------------
output "primary_redis_instances" {
  description = "Details of primary Redis cache instances"
  value = {
    for key, instance in azurerm_redis_enterprise_cache.primary : key => {
      id                = instance.id
      name              = instance.name
      hostname          = instance.hostname
      location          = instance.location
      sku_name          = instance.sku_name
      zones             = instance.zones
      resource_group    = instance.resource_group_name
    }
  }
}

#---------------------------------
# Replica Redis Instance Outputs  
#---------------------------------
output "replica_redis_instances" {
  description = "Details of replica Redis cache instances"
  value = local.replica_enabled ? {
    for key, instance in azurerm_redis_enterprise_cache.replica : key => {
      id                = instance.id
      name              = instance.name
      hostname          = instance.hostname
      location          = instance.location
      sku_name          = instance.sku_name
      zones             = instance.zones
      resource_group    = instance.resource_group_name
    }
  } : {}
}

#---------------------------------
# User Assigned Identity Outputs
#---------------------------------
output "primary_redis_identities" {
  description = "User assigned identities for primary Redis instances"
  value = {
    for key, identity in azurerm_user_assigned_identity.redis_primary : key => {
      id           = identity.id
      name         = identity.name
      principal_id = identity.principal_id
      client_id    = identity.client_id
      location     = identity.location
    }
  }
}

output "replica_redis_identities" {
  description = "User assigned identities for replica Redis instances"
  value = local.replica_enabled ? {
    for key, identity in azurerm_user_assigned_identity.redis_replica : key => {
      id           = identity.id
      name         = identity.name
      principal_id = identity.principal_id
      client_id    = identity.client_id
      location     = identity.location
    }
  } : {}
}

#---------------------------------
# Private Endpoint Outputs
#---------------------------------
output "primary_private_endpoints" {
  description = "Private endpoint details for primary Redis instances"
  value = {
    for key, pe in azurerm_private_endpoint.redis_primary : key => {
      id                = pe.id
      name              = pe.name
      private_ip        = pe.private_service_connection[0].private_ip_address
      fqdn              = pe.custom_dns_configs[0].fqdn
      location          = pe.location
    }
  }
  sensitive = False
}

output "replica_private_endpoints" {
  description = "Private endpoint details for replica Redis instances"
  value = local.replica_enabled ? {
    for key, pe in azurerm_private_endpoint.redis_replica : key => {
      id                = pe.id
      name              = pe.name
      private_ip        = pe.private_service_connection[0].private_ip_address
      fqdn              = pe.custom_dns_configs[0].fqdn
      location          = pe.location
    }
  } : {}
  sensitive = False
}

#---------------------------------
# Geo-Replication Status
#---------------------------------
output "geo_replication_config" {
  description = "Geo-replication configuration status"
  value = local.replica_enabled ? {
    enabled = true
    primary_instances = [
      for config in var.managed_redis_geo_replication_config : 
      config.primary_redis_key
    ]
    replica_instances = flatten([
      for config in var.managed_redis_geo_replication_config : 
      config.replica_keys
    ])
    geo_groups = [
      for config in var.managed_redis_config : 
      config.default_database.geo_replication_group_name
      if config.default_database.geo_replication_group_name != null
    ]
  } : {
    enabled = false
    message = "Geo-replication not configured or replica inputs missing"
  }
}

#---------------------------------
# Connection Information
#---------------------------------
output "redis_connection_info" {
  description = "Connection information for Redis instances (use with caution in logs)"
  value = {
    primary_connections = {
      for key, instance in azurerm_redis_enterprise_cache.primary : key => {
        hostname = instance.hostname
        port     = 6380  # Default SSL port for Redis Enterprise
        ssl_required = true
        private_endpoint_fqdn = try(
          azurerm_private_endpoint.redis_primary[key].custom_dns_configs[0].fqdn, 
          "No private endpoint configured"
        )
      }
    }
    replica_connections = local.replica_enabled ? {
      for key, instance in azurerm_redis_enterprise_cache.replica : key => {
        hostname = instance.hostname
        port     = 6380  # Default SSL port for Redis Enterprise
        ssl_required = true
        private_endpoint_fqdn = try(
          azurerm_private_endpoint.redis_replica[key].custom_dns_configs[0].fqdn,
          "No private endpoint configured"
        )
      }
    } : {}
  }
  sensitive = true  # Mark as sensitive to avoid logging connection details
}

#---------------------------------
# Resource Summary
#---------------------------------
output "deployment_summary" {
  description = "Summary of deployed Redis infrastructure"
  value = {
    primary_region     = var.location
    replica_region     = var.location_replica
    replica_enabled    = local.replica_enabled
    primary_instances  = length(var.managed_redis_config)
    replica_instances  = length(var.managed_redis_config_replica)
    geo_replication_groups = length(var.managed_redis_geo_replication_config)
    deployment_time    = timestamp()
    
    # Cost estimation helpers
    sku_summary = {
      primary_skus = [
        for config in var.managed_redis_config : config.sku_name
      ]
      replica_skus = local.replica_enabled ? [
        for config in var.managed_redis_config_replica : config.sku_name
      ] : []
    }
  }
}