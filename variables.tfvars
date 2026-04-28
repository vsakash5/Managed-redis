#==============================================================================
# EXAMPLE TERRAFORM VARIABLES - MINIMAL CONFIGURATION
# This file shows a minimal configuration for testing the Redis deployment
# without geo-replication (single region setup)
#==============================================================================

# Basic configuration
environment         = "development"
location            = "eastus2"
resource_group_name = "rg-redis-dev-eastus2"
context_prefix      = "demo"

# Simple tags for development
tags = {
  Environment = "development"
  Project     = "redis-demo"
  ManagedBy   = "terraform"
  Owner       = "platform-team"
}

# Network configuration (update with your existing resources)
snet_datasource_config = {
  workload = {
    name                 = "snet-workload-eastus2-001"
    virtual_network_name = "vnet-demo-eastus2-001"
    resource_group_name  = "rg-networking-eastus2"
  }
}

# Key vault configuration (update with your existing key vault)
kv_datasource_config = {
  primary = {
    keyvault_name                = "kv-demo-eastus2-001"
    keyvault_resource_group_name = "rg-security-eastus2"
  }
}

# Redis configuration - single instance for development
managed_redis_config = {
  "redis-dev" = {
    context_suffix            = "cache"
    instance                  = "01"
    sku_name                  = "Enterprise_E10"
    high_availability_enabled = false  # Disable for cost savings in dev
    kv_key                    = "primary"
    
    default_database = {
      clustering_policy = "OSSCluster"
      eviction_policy   = "AllKeysLRU"
    }
  }
}

# Private endpoint configuration
managed_redis_pe_config = {
  "redis-dev-pe" = {
    context              = "pe"
    instance             = "01"
    is_manual_connection = false
    static_ip_required   = false
    group_ids            = ["redisEnterprise"]
    snet_key             = "workload"
    managed_redis_key    = "redis-dev"
  }
}

# No replica configuration for minimal setup
# managed_redis_config_replica = {}
# managed_redis_pe_config_replica = {}
# managed_redis_geo_replication_config = {}