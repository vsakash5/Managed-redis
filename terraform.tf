#==============================================================================
# TERRAFORM AND PROVIDER CONFIGURATION
# This file configures Terraform settings and required providers
#==============================================================================

terraform {
  # Specify minimum Terraform version
  required_version = ">= 1.0"

  # Required providers with version constraints
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    
    # For advanced Redis configuration if needed
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
  }

  # Optional: Configure remote backend for state management
  # Uncomment and configure for production use
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "stterraformstate001"
  #   container_name       = "tfstate"
  #   key                  = "redis-geo-replication.tfstate"
  # }
}

#==============================================================================
# AZURE PROVIDER CONFIGURATION
#==============================================================================

# Configure the Azure Provider
provider "azurerm" {
  features {
    # Configure provider features as needed
    
    # Key Vault configuration
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }

    # Resource Group configuration
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    # Redis configuration
    managed_disk {
      expand_without_downtime = true
    }
  }
}

# Configure Azure API provider for advanced resources
provider "azapi" {
  # This provider is used for resources not yet available in azurerm
  # or for accessing preview features
}