# Azure Redis Enterprise with Geo-Replication

This Terraform configuration demonstrates how to deploy Azure Redis Enterprise instances with geo-replication across multiple Azure regions for high availability and disaster recovery.

## Architecture Overview

The configuration creates:
- **Primary Redis Instance**: Deployed in the primary region (e.g., East US 2)
- **Replica Redis Instance**: Deployed in a secondary region (e.g., West US 2)
- **Geo-Replication**: Automatic synchronization between primary and replica
- **Private Endpoints**: Secure network access in both regions
- **Customer-Managed Encryption**: Using Azure Key Vault keys in each region
- **High Availability**: Zone redundancy within each region

## Key Features

- 🏭 **Enterprise-grade**: Uses Azure Redis Enterprise for advanced features
- 🌍 **Geo-Replication**: Automatic cross-region data synchronization
- 🔒 **Security**: Private endpoints and customer-managed encryption
- 🚀 **High Availability**: Zone redundancy and automatic failover
- 📊 **Monitoring**: Built-in Azure monitoring and alerting
- 🏷️ **Tagging**: Comprehensive resource tagging for management

## Prerequisites

Before deploying this configuration, ensure you have:

1. **Azure Subscription** with sufficient permissions
2. **Terraform** installed (version 1.0 or later)
3. **Azure CLI** configured with appropriate credentials
4. **Existing Resource Groups** in both regions
5. **Virtual Networks and Subnets** configured for private endpoints
6. **Key Vaults** with encryption keys in both regions
7. **Private DNS Zones** for Redis private endpoints

## File Structure

```
.
├── main.tf                 # Primary Redis resources and geo-replication
├── modules.tf              # Data sources and shared resources
├── variables.tf            # Variable definitions with validations
├── primary.tfvars          # Example configuration values
├── terraform.tf            # Provider and backend configuration
├── outputs.tf              # Output values for integration
└── README.md               # This documentation
```

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd azure-redis-geo-replication
   ```

2. **Configure variables**:
   - Copy `primary.tfvars` to `terraform.tfvars`
   - Update values to match your environment:
     ```hcl
     resource_group_name = "your-primary-rg"
     location           = "eastus2"
     # ... other variables
     ```

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Plan deployment**:
   ```bash
   terraform plan -var-file="terraform.tfvars"
   ```

5. **Deploy resources**:
   ```bash
   terraform apply -var-file="terraform.tfvars"
   ```

## Configuration Details

### Redis Configuration

The Redis instances use Enterprise tier for geo-replication support:

- **SKU**: Enterprise_E10 (or higher for production)
- **Clustering**: OSS Cluster mode for scalability
- **Eviction**: AllKeysLRU policy for memory management
- **Encryption**: Customer-managed keys for data at rest

### Network Security

- **Private Endpoints**: Redis instances are not publicly accessible
- **DNS Integration**: Private DNS zones for name resolution
- **Network Isolation**: Deploy in existing virtual networks

### Geo-Replication

- **Active-Passive**: Primary handles writes, replica for reads/failover
- **Automatic Sync**: Data synchronization managed by Azure
- **Failover**: Manual or automatic failover capabilities

## Important Considerations

### Cost Management
- Enterprise tier has higher costs than Basic/Standard
- Cross-region data transfer charges apply
- Consider reserved instances for production workloads

### Security Best Practices
- Use customer-managed keys for encryption
- Implement network security groups
- Enable Azure Security Center recommendations
- Regular security assessments

### Monitoring and Alerting
- Configure Azure Monitor alerts
- Set up log analytics workspace
- Monitor replication lag and performance
- Implement health checks

## Customization

### Adding More Regions
To add additional replica regions, update:
1. `managed_redis_config_replica` - Add new region configs
2. `snet_datasource_config` - Add network configs
3. `kv_datasource_config` - Add key vault configs
4. `managed_redis_geo_replication_config` - Link to primary

### Scaling Configuration
For higher throughput, consider:
- Upgrading to larger SKUs (E20, E50, E100)
- Implementing read replicas
- Optimizing clustering configuration
- Network performance tuning

## Troubleshooting

### Common Issues

1. **Private Endpoint DNS Resolution**
   - Verify private DNS zones are properly configured
   - Check DNS forwarders if using custom DNS

2. **Key Vault Access**
   - Ensure managed identity has proper permissions
   - Verify key vault firewall settings

3. **Geo-Replication Sync**
   - Monitor replication lag metrics
   - Check network connectivity between regions

### Useful Commands

```bash
# Check Redis status
az redis show --name <redis-name> --resource-group <rg-name>

# Monitor geo-replication
az redis geo-replication show --name <redis-name> --resource-group <rg-name>

# Test connectivity
az redis list-keys --name <redis-name> --resource-group <rg-name>
```

## Contributing

When contributing to this configuration:
1. Follow Terraform best practices
2. Add appropriate variable validations
3. Update documentation for changes
4. Test in non-production environment first

## License

This configuration is provided as-is for educational and demonstration purposes.

## Support

For issues specific to this configuration, please refer to:
- Azure Redis documentation
- Terraform Azure Provider documentation
- Azure support channels for platform-specific issues