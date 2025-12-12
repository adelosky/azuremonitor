# Script to create an Azure Monitor Data Collection Rule

# Parameters
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$DcrName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [string]$RuleFilePath,
    
    [Parameter(Mandatory=$false)]
    [string]$Description = "Data Collection Rule for Azure VM Metrics"
)

# Validate JSON file exists
if (-not (Test-Path $RuleFilePath)) {
    Write-Error "Rule file not found at: $RuleFilePath"
    exit 1
}

Write-Host "Creating Data Collection Rule: $DcrName" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host "Location: $Location" -ForegroundColor Cyan

try {
    # Create the DCR
    $dcr = az monitor data-collection rule create `
        --location $Location `
        --resource-group $ResourceGroup `
        --name $DcrName `
        --rule-file $RuleFilePath `
        --description $Description `
        --output json | ConvertFrom-Json
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nData Collection Rule created successfully!" -ForegroundColor Green
        Write-Host "DCR Resource ID: $($dcr.id)" -ForegroundColor Green
    }
    else {
        Write-Error "Failed to create Data Collection Rule"
        exit 1
    }
}
catch {
    Write-Error "Error creating DCR: $_"
    exit 1
}