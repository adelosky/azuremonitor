# Azure Monitoring
This repository is a collection of scripts, JSON files, and Azure Monitor Workbooks I have developed to help customers enable, configure and enhance Azure Monitoring for their environments.

## Repository Contents

### Data Collection Rules (DCRs)
- **Location**: `dcr/` folder
- **Purpose**: Contains Data Collection Rule templates and deployment scripts for various Azure services
- **Key Files**: 
  - `deploy-monitor-dcr.ps1` - PowerShell script for DCR deployment
  - `resourcemetrics-*.json` - DCR templates for different resource types

### Azure Monitor Workbooks
- **Location**: `artifacts/` folder
- **Purpose**: Pre-built Azure Monitor Workbooks for comprehensive monitoring dashboards

#### Arc-enabled SQL Server Monitoring Workbook
- **File**: `artifacts/ArcSQLServerMonitorWorkbook.json`
- **Purpose**: Comprehensive monitoring dashboard for Arc-enabled SQL Server instances
- **Features**:
  - **Overview Metrics**: Instance count, database count, security status
  - **Configuration Analysis**: SQL versions, editions, compatibility levels
  - **Security & Compliance**: Azure Defender status, encryption analysis
  - **Licensing Information**: License type distribution and classification
  - **Tag-based Analysis**: Customizable organizational grouping
  - **Detailed Inventory**: Complete instance and database information

**To Deploy the Workbook**:
1. Navigate to Azure Portal → Monitor → Workbooks
2. Click "New" → "Advanced Editor"
3. Copy and paste the JSON content from `ArcSQLServerMonitorWorkbook.json`
4. Click "Apply" → "Done Editing"
5. Save with a descriptive name

The workbook provides Resource Graph-based queries optimized for Arc-enabled SQL Server monitoring, offering insights into your entire SQL Server estate including inventory, configuration, security status, and compliance metrics.
