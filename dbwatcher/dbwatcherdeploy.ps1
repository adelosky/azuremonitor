<#
.SYNOPSIS
  End-to-end setup of Database Watcher (preview) for Azure SQL Database using ADX as data store.
  Creates/uses: RGs, ADX cluster+DB, deploys official Database Watcher ARM template, adds SQL DB targets, and starts the watcher.
 
.NOTES
  Learn docs: Monitor Azure SQL with Database Watcher (preview)
  Code sample (ARM/Bicep): "Enable database watcher for Azure SQL" quickstart
#>
 
param(
  [Parameter(Mandatory=$true)] [string] $SubscriptionId,
  [Parameter(Mandatory=$true)] [string] $Location,                     # e.g., eastus
  [Parameter(Mandatory=$true)] [string] $WatcherRgName,                # e.g., rg-dbw-eus
  [Parameter(Mandatory=$true)] [string] $WatcherName,                  # e.g., dbw-eus
  [Parameter(Mandatory=$true)] [string] $AdxRgName,                    # e.g., rg-adx-eus
  [Parameter(Mandatory=$true)] [string] $AdxClusterName,               # e.g., adx-dbw-eus
  [Parameter(Mandatory=$true)] [string] $AdxDatabaseName,              # e.g., dbwatcher
  [Parameter(Mandatory=$true)] [array]  $SqlTargets,                   # Array of hashtables; see EXAMPLE below
  [switch] $UseManagedPrivateEndpoints,                                # Creates MPEs to SQL server (and Key Vault when SQL auth)
  [ValidateSet('EntraID','Sql')] [string] $AuthenticationType = 'EntraID',
  [string] $TemplateUri = "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/quickstarts/microsoft.databasewatcher/create-watcher/azuredeploy.json"
)
 
<#
.EXAMPLE (pass -SqlTargets):
  @(
    @{ serverResourceId = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Sql/servers/<serverName>";
       databaseResourceId = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Sql/servers/<serverName>/databases/<dbName>" }
    # add more entries as needed
  )
#>
 
#---------------------------
# 0) Login & subscription
#---------------------------
Write-Host "Signing in (if needed) and selecting subscription..." -ForegroundColor Cyan
try {
  if (-not (Get-AzContext)) { Connect-AzAccount -ErrorAction Stop | Out-Null }
} catch { Connect-AzAccount -ErrorAction Stop | Out-Null }
Select-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
 
#---------------------------
# 1) Register resource providers (idempotent)
#---------------------------
$providers = @(
  "Microsoft.DatabaseWatcher",
  "Microsoft.Kusto",
  "Microsoft.Network",
  "Microsoft.Insights"     # alerts
)
if ($AuthenticationType -eq 'Sql') { $providers += "Microsoft.KeyVault" } # needed if using SQL auth
 
foreach ($p in $providers) {
  $rp = Get-AzResourceProvider -ProviderNamespace $p -ErrorAction SilentlyContinue
  if (-not $rp -or $rp.RegistrationState -ne 'Registered') {
    Write-Host "Registering resource provider: $p ..." -ForegroundColor Yellow
    Register-AzResourceProvider -ProviderNamespace $p | Out-Null
  }
}
 
#---------------------------
# 2) Resource groups
#---------------------------
foreach ($rg in @($WatcherRgName, $AdxRgName)) {
  if (-not (Get-AzResourceGroup -Name $rg -ErrorAction SilentlyContinue)) {
    Write-Host "Creating resource group: $rg in $Location ..." -ForegroundColor Yellow
    New-AzResourceGroup -Name $rg -Location $Location | Out-Null
  } else {
    Write-Host "Using existing resource group: $rg" -ForegroundColor Green
  }
}
 
#---------------------------
# 3) ADX cluster + database (or reuse if present)
#---------------------------
# Cluster
$adxCluster = Get-AzKustoCluster -Name $AdxClusterName -ResourceGroupName $AdxRgName -ErrorAction SilentlyContinue
if (-not $adxCluster) {
  Write-Host "Creating ADX cluster $AdxClusterName ..." -ForegroundColor Yellow
  # Sizing: Dev/test minimal SKU; adjust as needed.
  $adxCluster = New-AzKustoCluster `
      -ResourceGroupName $AdxRgName `
      -Name $AdxClusterName `
      -Location $Location `
      -SkuName "Dev(No SLA)_Standard_D11_v2" `
      -SkuCapacity 1
} else {
  Write-Host "Using existing ADX cluster: $AdxClusterName" -ForegroundColor Green
}
 
# Database
$adxDb = Get-AzKustoDatabase -ResourceGroupName $AdxRgName -ClusterName $AdxClusterName -Name $AdxDatabaseName -ErrorAction SilentlyContinue
if (-not $adxDb) {
  Write-Host "Creating ADX database $AdxDatabaseName ..." -ForegroundColor Yellow
  $adxDb = New-AzKustoDatabase `
      -ResourceGroupName $AdxRgName `
      -ClusterName $AdxClusterName `
      -Name $AdxDatabaseName `
      -Kind ReadWrite
} else {
  Write-Host "Using existing ADX database: $AdxDatabaseName" -ForegroundColor Green
}
 
# Build Kusto resource IDs for template params
$adxClusterId  = $adxCluster.Id
 
#---------------------------
# 4) Prepare template parameters
#---------------------------
# Fetch template if you prefer a local file:
#   Invoke-WebRequest -Uri $TemplateUri -OutFile ".\azuredeploy.json"
 
# The official template expects parameters like watcherName, location, kusto* and sqlTargets (see the sample page).
# We’ll create a parameter object dynamically.
 
# Normalize SqlTargets to the expected array of objects
$targetsParam = @()
foreach ($t in $SqlTargets) {
  if (-not $t.serverResourceId -or -not $t.databaseResourceId) {
    throw "Each SqlTargets entry must include serverResourceId and databaseResourceId."
  }
  $targetsParam += @{
    serverResourceId   = $t.serverResourceId
    databaseResourceId = $t.databaseResourceId
    # For future extension: authenticationType ('EntraID' or 'Sql') per target, managed identity, etc.
  }
}
 
# Build parameter hashtable (align with the Learn sample’s schema)
$deploymentParams = @{
  watcherName            = @{ value = $WatcherName }
  location               = @{ value = $Location }
  kustoClusterResourceId = @{ value = $adxClusterId }
  kustoDatabaseName      = @{ value = $AdxDatabaseName }
  sqlTargets             = @{ value = $targetsParam }
  authenticationType     = @{ value = $AuthenticationType }        # 'EntraID' (recommended) or 'Sql'
  createManagedPrivateEndpoints = @{ value = [bool]$UseManagedPrivateEndpoints }
}
 
#---------------------------
# 5) Deploy the watcher via ARM template
#---------------------------
Write-Host "Deploying Database Watcher $WatcherName to $WatcherRgName ..." -ForegroundColor Cyan
$deploymentName = "dbwatcher-$($WatcherName)-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
 
New-AzResourceGroupDeployment `
  -Name $deploymentName `
  -ResourceGroupName $WatcherRgName `
  -TemplateUri $TemplateUri `
  -TemplateParameterObject $deploymentParams `
  -Verbose -ErrorAction Stop
 
Write-Host "Deployment submitted. Validating..." -ForegroundColor Green
 
#---------------------------
# 6) (Optional) Start the watcher explicitly if template doesn’t auto-start
#    Some samples start the watcher; if needed, you can call REST to start it.
#---------------------------
# Example using Az REST:
# $watcherId = "/subscriptions/$SubscriptionId/resourceGroups/$WatcherRgName/providers/Microsoft.DatabaseWatcher/watchers/$WatcherName"
# Invoke-AzRestMethod -Method POST -Path "$watcherId/start?api-version=2024-03-15-preview"
 
Write-Host "Database Watcher setup complete." -ForegroundColor Green
Write-Host "Watcher name: $WatcherName" -ForegroundColor Green
Write-Host "ADX database: $AdxRgName/$AdxClusterName/$AdxDatabaseName" -ForegroundColor Green