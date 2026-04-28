#==============================================================================
# TERRAFORM VARIABLES DEFINITION
# This file defines all input variables for the Redis cache geo-replication
# deployment, including descriptions and default values
#==============================================================================

#-----------------------------
# Basic Infrastructure Variables
#-----------------------------
variable "resource_group_name" {
  type        = string
  description = "(Required) Name of the primary region Resource Group."
}

variable "environment" {
  type        = string
  description = "(Required) Environment name (e.g., 'production', 'staging', 'development')."
  
  validation {
    condition     = contains(["production", "staging", "development", "test"], var.environment)
    error_message = "Environment must be one of: production, staging, development, test."
  }
}

variable "location" {
  type        = string
  description = "(Required) Primary Azure region for resource deployment."
  
  validation {
    condition = can(regex("^[a-z0-9]+$", var.location))
    error_message = "Location must be a valid Azure region name."
  }
}

variable "context_prefix" {
  type        = string
  description = "(Required) Prefix used in resource naming for context identification."
  
  validation {
    condition     = length(var.context_prefix) <= 10
    error_message = "Context prefix must be 10 characters or less."
  }
}

#-----------------------------
# Replica Region Variables (Optional)
#-----------------------------
variable "environment_replica" {
  type        = string
  description = "(Optional) Environment name for replica region - should match primary for geo-replication."
  default     = null
}

variable "location_replica" {
  type        = string
  description = "(Optional) Replica Azure region for geo-replication setup."
  default     = null
}

variable "resource_group_name_replica" {
  type        = string
  description = "(Optional) Name of the replica region Resource Group."
  default     = null
}

variable "context_prefix_replica" {
  type        = string
  description = "(Optional) Context prefix for replica region resources."
  default     = null
}

#-----------------------------
# Resource Tags
#-----------------------------
variable "tags" {
  type        = map(any)
  description = "(Optional) Map of tags to apply to all resources."
  default = {
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

#--------------------------
# Network Data Source Variables
# Configuration for existing network resources
#--------------------------
variable "vnet_datasource_config" {
  type = map(object({
    name                = string
    resource_group_name = string
  }))
  description = "(Optional) Configuration for existing virtual networks."
  default     = {}
}

variable "snet_datasource_config" {
  type = map(object({
    name                 = string
    virtual_network_name = string
    resource_group_name  = string
  }))
  description = "(Optional) Configuration for existing subnets used by private endpoints."
  default     = {}
}

variable "kv_datasource_config" {
  type = map(object({
    keyvault_name                = string
    keyvault_resource_group_name = string
  }))
  description = "(Optional) Configuration for existing Key Vaults containing encryption keys."
  default     = {}
}

#---------------------------------
# Redis Cache Configuration
# Primary and replica Redis instances
#---------------------------------
variable "managed_redis_config" {
  type = map(object({
    context_suffix            = string
    instance                  = string
    sku_name                  = string
    high_availability_enabled = bool
    kv_key                    = string
    expiration_date           = optional(string, "2025-12-31T23:59:59Z")
    
    default_database = object({
      clustering_policy          = optional(string, "OSSCluster")
      eviction_policy            = optional(string, "AllKeysLRU")
      geo_replication_group_name = optional(string)
    })
  }))
  description = "(Optional) Configuration map for primary region Redis cache instances."
  
  default = {
    "redis-default" = {
      context_suffix            = "cache"
      instance                  = "01"
      sku_name                  = "Enterprise_E10"
      high_availability_enabled = true
      kv_key                    = "primary"
      expiration_date           = "2025-12-31T23:59:59Z"
      
      default_database = {
        clustering_policy          = "OSSCluster"
        eviction_policy            = "AllKeysLRU"
        geo_replication_group_name = "default-geo-group"
      }
    }
  }
  
  validation {
    condition = alltrue([
      for config in var.managed_redis_config : 
      contains(["Enterprise_E10", "Enterprise_E20", "Enterprise_E50", "Enterprise_E100"], config.sku_name)
    ])
    error_message = "SKU name must be an Enterprise tier for geo-replication support."
  }
}

variable "managed_redis_config_replica" {
  type = map(object({
    context_suffix            = string
    instance                  = string
    sku_name                  = string
    high_availability_enabled = bool
    kv_key_replica            = string
    expiration_date           = optional(string, "2025-12-31T23:59:59Z")
    
    default_database = object({
      clustering_policy          = optional(string, "OSSCluster")
      eviction_policy            = optional(string, "AllKeysLRU")
      geo_replication_group_name = optional(string)
    })
  }))
  description = "(Optional) Configuration map for replica region Redis cache instances."
  default     = {}
}

#---------------------------------
# Private Endpoint Configuration
# Network security for Redis access
#---------------------------------
variable "managed_redis_pe_config" {
  type = map(object({
    context                           = string
    instance                          = string
    is_manual_connection              = bool
    private_connection_resource_alias = optional(string)
    static_ip_required                = bool
    static_ip_address                 = optional(string)
    group_ids                         = list(string)
    snet_key                          = string
    managed_redis_key                 = string
  }))
  description = "(Optional) Configuration for Redis private endpoints in primary region."
  default     = {}
  
  validation {
    condition = alltrue([
      for config in var.managed_redis_pe_config : 
      contains(config.group_ids, "redisEnterprise")
    ])
    error_message = "Private endpoint group_ids must include 'redisEnterprise'."
  }
}

variable "managed_redis_pe_config_replica" {
  type = map(object({
    context                           = string
    instance                          = string
    is_manual_connection              = bool
    private_connection_resource_alias = optional(string)
    static_ip_required                = bool
    static_ip_address                 = optional(string)
    group_ids                         = list(string)
    snet_key_replica                  = string
    managed_redis_key_replica         = string
  }))
  description = "(Optional) Configuration for Redis private endpoints in replica region."
  default     = {}
}

#---------------------------------
# Geo-Replication Configuration
# Links primary and replica instances
#---------------------------------
variable "managed_redis_geo_replication_config" {
  type = map(object({
    primary_redis_key = string
    replica_keys      = list(string)
  }))
  description = "(Optional) Configuration for Redis geo-replication linking primary to replica instances."
  default     = {}
  
  validation {
    condition = alltrue([
      for config in var.managed_redis_geo_replication_config : 
      length(config.replica_keys) > 0
    ])
    error_message = "Geo-replication configuration must specify at least one replica key."
  }
}