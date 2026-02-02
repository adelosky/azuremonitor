# Arc SQL Server Monitoring Workbook

This Azure Monitor Workbook provides comprehensive insights into your Arc-enabled SQL Server estate, including inventory, configuration, security, and compliance status.

## Overview

The workbook leverages Azure Resource Graph queries to provide visibility into:
- **Overview Metrics**: Instance counts, database counts, security status
- **Configuration Analysis**: SQL Server versions, editions, compatibility levels
- **Security & Compliance**: Azure Defender status, encryption status
- **Licensing Information**: License types and edition distribution
- **Tag-based Analysis**: Organizational groupings (customizable)
- **Detailed Inventory**: Complete Arc SQL Server instance details

## Prerequisites

- Azure subscription with Arc-enabled SQL Server instances
- **Reader** permissions on the target subscription(s)
- **Monitoring Reader** or **Monitoring Contributor** role for Azure Monitor
- Azure Resource Graph access (included with Reader permissions)

## Deployment Options

### Option 1: Manual Deployment (Testing & Development)

For initial testing and small-scale deployments:

1. **Navigate to Azure Monitor Workbooks**
   - Go to [Azure Monitor](https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/workbooks) in Azure Portal
   - Select **Workbooks** > **New**

2. **Import the Workbook**
   - Click **Advanced Editor** (</> icon)
   - Replace the default JSON with the content from `ArcSQLServerMonitorWorkbook.json`
   - Click **Apply**

3. **Configure Parameters**
   - Select target subscription(s)
   - Choose resource groups (or leave as "All")

4. **Save the Workbook**
   - Click **Save**
   - Choose **Shared Workbook** for team access
   - Select appropriate resource group and region

### Option 2: ARM Template Deployment (Recommended for Scale)

For enterprise and production deployments:

#### Create ARM Template

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "workbookDisplayName": {
            "type": "string",
            "defaultValue": "Arc SQL Server Monitoring",
            "metadata": {
                "description": "Display name for the workbook"
            }
        },
        "workbookSourceId": {
            "type": "string",
            "defaultValue": "Azure Monitor",
            "metadata": {
                "description": "Source ID for the workbook"
            }
        }
    },
    "variables": {
        "workbookContent": "[replace(replace(string(json(base64ToString('<<BASE64_ENCODED_JSON>>'))), '\\\"', '\\\\\\\"'), '\\n', '\\\\n')]"
    },
    "resources": [
        {
            "type": "Microsoft.Insights/workbooks",
            "apiVersion": "2022-04-01",
            "name": "[guid(parameters('workbookDisplayName'))]",
            "location": "[resourceGroup().location]",
            "properties": {
                "displayName": "[parameters('workbookDisplayName')]",
                "serializedData": "[variables('workbookContent')]",
                "category": "workbook",
                "sourceId": "[parameters('workbookSourceId')]"
            }
        }
    ],
    "outputs": {
        "workbookId": {
            "type": "string",
            "value": "[resourceId('Microsoft.Insights/workbooks', guid(parameters('workbookDisplayName')))]"
        }
    }
}
```

#### Deploy via Azure CLI

```bash
# Create resource group (if needed)
az group create --name "rg-monitoring-workbooks" --location "East US"

# Deploy the workbook
az deployment group create \
  --resource-group "rg-monitoring-workbooks" \
  --template-file "arc-sql-workbook-template.json" \
  --parameters workbookDisplayName="Arc SQL Server Monitoring - Production"
```

#### Deploy via PowerShell

```powershell
# Create resource group (if needed)
New-AzResourceGroup -Name "rg-monitoring-workbooks" -Location "East US"

# Deploy the workbook
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-monitoring-workbooks" `
  -TemplateFile "arc-sql-workbook-template.json" `
  -workbookDisplayName "Arc SQL Server Monitoring - Production"
```

### Option 3: Bicep Template Deployment

Create `arc-sql-workbook.bicep`:

```bicep
@description('Display name for the workbook')
param workbookDisplayName string = 'Arc SQL Server Monitoring'

@description('Location for the workbook')
param location string = resourceGroup().location

@description('Source ID for the workbook')
param workbookSourceId string = 'Azure Monitor'

var workbookContent = loadTextContent('ArcSQLServerMonitorWorkbook.json')

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(workbookDisplayName)
  location: location
  properties: {
    displayName: workbookDisplayName
    serializedData: workbookContent
    category: 'workbook'
    sourceId: workbookSourceId
  }
}

output workbookId string = workbook.id
```

Deploy with:

```bash
az deployment group create \
  --resource-group "rg-monitoring-workbooks" \
  --template-file "arc-sql-workbook.bicep" \
  --parameters workbookDisplayName="Arc SQL Server Monitoring"
```

## Enterprise Deployment Best Practices

### 1. **Centralized Deployment**
- Deploy to a dedicated monitoring resource group
- Use a central subscription for monitoring resources
- Grant cross-subscription read access for multi-tenant scenarios

### 2. **Role-Based Access Control (RBAC)**
```bash
# Grant workbook access to monitoring team
az role assignment create \
  --assignee-object-id "<team-group-id>" \
  --role "Monitoring Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-monitoring-workbooks"

# Grant read access to Arc resources across subscriptions
az role assignment create \
  --assignee-object-id "<team-group-id>" \
  --role "Reader" \
  --scope "/subscriptions/<target-subscription-id>"
```

### 3. **CI/CD Integration**

Example GitHub Actions workflow:

```yaml
name: Deploy Arc SQL Monitoring Workbook

on:
  push:
    branches: [ main ]
    paths: [ 'monitor/**' ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Deploy Workbook
      uses: azure/arm-deploy@v1
      with:
        subscriptionId: ${{ secrets.AZURE_SUBSCRIPTION }}
        resourceGroupName: rg-monitoring-workbooks
        template: ./monitor/arc-sql-workbook-template.json
        parameters: workbookDisplayName="Arc SQL Server Monitoring"
```

### 4. **Multi-Environment Strategy**
- **Development**: Manual deployment for testing
- **Staging**: ARM template deployment with validation
- **Production**: Automated CI/CD with approval gates

## Customization Guidelines

### Tag-Based Analysis
The workbook includes tag-based analysis sections. Update these queries to match your organization's tagging strategy:

- **Application** tag: `tags.Application`
- **Location** tag: `tags.Location` 
- **DataCenter** tag: `tags.DataCenter`
- **BusinessUnit** tag: `tags.BusinessUnit`

Example modification:
```kql
// Change from tags.Application to tags.Environment
| extend environment = tostring(tags.Environment)
| where isnotempty(environment)
| summarize ServerCount = count() by environment
```

### Adding Custom Metrics
To add custom visualizations:

1. Identify the Resource Graph query pattern
2. Add new workbook item in the JSON
3. Test the query in Azure Resource Graph Explorer
4. Update the workbook JSON with the new visualization

### Regional Deployment
For multi-region scenarios, consider:
- Deploying workbooks in each region for performance
- Using workbook parameters to filter by region
- Creating region-specific versions for compliance

## Troubleshooting

### Common Issues

1. **"No data" in visualizations**
   - Verify Arc SQL Server extension is installed and reporting
   - Check subscription and resource group filters
   - Ensure proper RBAC permissions

2. **Permission errors**
   - Verify **Reader** role on target subscriptions
   - Check **Monitoring Reader** role for Azure Monitor access

3. **Query timeouts**
   - Reduce time range or add more specific filters
   - Consider breaking large queries into smaller sections

### Validation Steps

```bash
# Check Arc SQL Server instances are reporting
az graph query -q "resources | where type == 'microsoft.azurearcdata/sqlserverinstances' | count"

# Verify database resources
az graph query -q "resources | where type == 'microsoft.azurearcdata/sqlserverinstances/databases' | count"

# Check permissions
az role assignment list --scope "/subscriptions/<subscription-id>" --assignee "<user-or-group-id>"
```

## Monitoring and Maintenance

### Regular Tasks
- **Monthly**: Review and update tag-based queries
- **Quarterly**: Validate data accuracy against known inventory
- **Annually**: Update workbook for new Arc SQL Server features

### Version Control
- Store workbook JSON in source control
- Use semantic versioning for releases
- Maintain changelog for updates

## Support and Documentation

- **Azure Monitor Workbooks**: [Official Documentation](https://docs.microsoft.com/azure/azure-monitor/visualize/workbooks-overview)
- **Azure Resource Graph**: [Query Reference](https://docs.microsoft.com/azure/governance/resource-graph/reference/supported-tables-resources)
- **Arc SQL Server**: [Monitoring Documentation](https://docs.microsoft.com/sql/sql-server/azure-arc/assess)

## Contributing

To contribute improvements:
1. Test changes in development environment
2. Update this README with any new features
3. Submit changes via pull request
4. Include validation screenshots and test results