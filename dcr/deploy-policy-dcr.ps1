#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Azure Policy to assign Data Collection Rules to Arc-enabled Virtual Machines

.DESCRIPTION
    This script creates and assigns an Azure Policy that automatically associates
    Data Collection Rules with Arc-enabled Virtual Machines in a subscription.

.PARAMETER SubscriptionId
    The Azure subscription ID where the policy will be deployed

.PARAMETER ResourceGroupName
    The resource group containing the Data Collection Rule

.PARAMETER DataCollectionRuleName
    The name of the Data Collection Rule to associate with Arc-enabled VMs

.PARAMETER PolicyAssignmentName
    The name for the policy assignment (default: arc-dcr-assignment)

.PARAMETER Location
    The Azure region for the policy assignment (default: East US)

.PARAMETER UseBuiltInPolicies
    Use Microsoft's built-in policy initiatives instead of custom policy

.EXAMPLE
    ./deploy-arc-dcr-policy.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "rg-monitoring" -DataCollectionRuleName "dcr-vm-monitoring"

.EXAMPLE
    ./deploy-arc-dcr-policy.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "rg-monitoring" -DataCollectionRuleName "dcr-vm-monitoring" -UseBuiltInPolicies
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$DataCollectionRuleName,
    
    [Parameter(Mandatory = $false)]
    [string]$PolicyAssignmentName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseBuiltInPolicies
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Azure Policy deployment for Arc-enabled VMs and Data Collection Rules" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Yellow

# Set the subscription context
Write-Host "📋 Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set subscription context"
    exit 1
}

# Get the Data Collection Rule resource ID
Write-Host "🔍 Getting Data Collection Rule resource ID..." -ForegroundColor Cyan
$dcrResourceId = az monitor data-collection rule show `
    --resource-group $ResourceGroupName `
    --data-collection-rule-name $DataCollectionRuleName `
    --query "id" `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($dcrResourceId)) {
    Write-Error "Failed to get Data Collection Rule resource ID. Please ensure the DCR exists."
    exit 1
}

Write-Host "✅ DCR Resource ID: $dcrResourceId" -ForegroundColor Green

if ($UseBuiltInPolicies) {
    Write-Host "🏗️ Using Microsoft's built-in policy initiatives..." -ForegroundColor Cyan
    
    # Built-in initiative IDs
    $windowsInitiativeId = "9575b8b7-78ab-4281-b53b-d3c1ace2260b"
    $linuxInitiativeId = "118f04da-0375-44d1-84e3-0fd9e1849403"
    
    Write-Host "📝 Assigning Windows Arc-enabled machines policy..." -ForegroundColor Cyan
    az policy assignment create `
        --name "$PolicyAssignmentName-windows" `
        --display-name "Configure Windows Arc-enabled machines with DCR" `
        --description "Automatically configure Windows Arc-enabled servers with Azure Monitor Agent and associate with DCR" `
        --policy-set-definition $windowsInitiativeId `
        --scope "/subscriptions/$SubscriptionId" `
        --params "{\"dataCollectionRuleResourceId\": {\"value\": \"$dcrResourceId\"}}" `
        --mi-system-assigned `
        --location $Location
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to assign Windows policy"
        exit 1
    }
    
    Write-Host "📝 Assigning Linux Arc-enabled machines policy..." -ForegroundColor Cyan
    az policy assignment create `
        --name "$PolicyAssignmentName-linux" `
        --display-name "Configure Linux Arc-enabled machines with DCR" `
        --description "Automatically configure Linux Arc-enabled servers with Azure Monitor Agent and associate with DCR" `
        --policy-set-definition $linuxInitiativeId `
        --scope "/subscriptions/$SubscriptionId" `
        --params "{\"dataCollectionRuleResourceId\": {\"value\": \"$dcrResourceId\"}}" `
        --mi-system-assigned `
        --location $Location
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to assign Linux policy"
        exit 1
    }
    
    Write-Host "✅ Built-in policy initiatives assigned successfully" -ForegroundColor Green
    
} else {
    Write-Host "🏗️ Creating custom policy definition..." -ForegroundColor Cyan
    
    # Create the policy definition JSON (rules only, without mode)
    $policyRules = @"
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.HybridCompute/machines"
      },
      {
        "field": "Microsoft.HybridCompute/machines/osName",
        "in": ["Windows", "Linux"]
      }
    ]
  },
  "then": {
    "effect": "deployIfNotExists",
    "details": {
      "type": "Microsoft.Insights/dataCollectionRuleAssociations",
      "name": "[concat('dcr-association-', parameters('dataCollectionRuleName'))]",
      "roleDefinitionIds": [
        "/providers/microsoft.authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa",
        "/providers/microsoft.authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293"
      ],
      "existenceCondition": {
        "field": "Microsoft.Insights/dataCollectionRuleAssociations/dataCollectionRuleId",
        "equals": "[parameters('dataCollectionRuleId')]"
      },
      "deployment": {
        "properties": {
          "mode": "incremental",
          "template": {
            "`$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
            "contentVersion": "1.0.0.0",
            "parameters": {
              "vmName": {
                "type": "string"
              },
              "dataCollectionRuleId": {
                "type": "string"
              }
            },
            "resources": [
              {
                "type": "Microsoft.Insights/dataCollectionRuleAssociations",
                "apiVersion": "2021-09-01-preview",
                "scope": "[concat('Microsoft.HybridCompute/machines/', parameters('vmName'))]",
                "name": "[concat('dcr-association-', uniqueString(parameters('dataCollectionRuleId')))]",
                "properties": {
                  "description": "Association of data collection rule with Arc-enabled server",
                  "dataCollectionRuleId": "[parameters('dataCollectionRuleId')]"
                }
              }
            ]
          },
          "parameters": {
            "vmName": {
              "value": "[field('name')]"
            },
            "dataCollectionRuleId": {
              "value": "[parameters('dataCollectionRuleId')]"
            }
          }
        }
      }
    }
  }
}
"@

    # Create the policy parameters JSON
    $policyParameters = @"
{
  "dataCollectionRuleId": {
    "type": "String",
    "metadata": {
      "displayName": "Data Collection Rule ID",
      "description": "Resource ID of the Data Collection Rule to associate with Arc-enabled servers"
    }
  },
  "dataCollectionRuleName": {
    "type": "String",
    "metadata": {
      "displayName": "Data Collection Rule Name",
      "description": "Name of the Data Collection Rule"
    }
  }
}
"@

    # Save policy rules to temporary file
    $tempRulesFile = [System.IO.Path]::GetTempFileName() + ".json"
    $policyRules | Out-File -FilePath $tempRulesFile -Encoding UTF8
    
    # Save policy parameters to temporary file  
    $tempParametersFile = [System.IO.Path]::GetTempFileName() + ".json"
    $policyParameters | Out-File -FilePath $tempParametersFile -Encoding UTF8
    
    Write-Host "📄 Policy rules saved to: $tempRulesFile" -ForegroundColor Yellow
    Write-Host "📄 Policy parameters saved to: $tempParametersFile" -ForegroundColor Yellow
    
    # Create the policy definition
    Write-Host "📝 Creating custom policy definition..." -ForegroundColor Cyan
    az policy definition create `
        --name "arc-servers-dcr-assignment" `
        --display-name "Deploy Data Collection Rule Association for Arc-enabled Servers" `
        --description "Automatically associate Arc-enabled servers with specified Data Collection Rule" `
        --rules $tempRulesFile `
        --params $tempParametersFile `
        --mode "Indexed"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create policy definition"
        Remove-Item $tempRulesFile -Force
        Remove-Item $tempParametersFile -Force
        exit 1
    }
    
    Write-Host "📝 Assigning custom policy..." -ForegroundColor Cyan
    
    # Create assignment parameters JSON
    $assignmentParameters = @"
{
  "dataCollectionRuleId": {
    "value": "$dcrResourceId"
  },
  "dataCollectionRuleName": {
    "value": "$DataCollectionRuleName"
  }
}
"@
    
    # Save assignment parameters to temporary file
    $tempAssignmentParamsFile = [System.IO.Path]::GetTempFileName() + ".json"
    $assignmentParameters | Out-File -FilePath $tempAssignmentParamsFile -Encoding UTF8
    
    Write-Host "📄 Assignment parameters saved to: $tempAssignmentParamsFile" -ForegroundColor Yellow
    
    az policy assignment create `
        --name $PolicyAssignmentName `
        --display-name "Assign DCR to Arc-enabled Servers" `
        --description "Automatically assigns Data Collection Rules to Arc-enabled Virtual Machines" `
        --scope "/subscriptions/$SubscriptionId" `
        --policy "arc-servers-dcr-assignment" `
        --params $tempAssignmentParamsFile `
        --mi-system-assigned `
        --location $Location
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to assign policy"
        Remove-Item $tempRulesFile -Force
        Remove-Item $tempParametersFile -Force
        Remove-Item $tempAssignmentParamsFile -Force
        exit 1
    }
    
    # Clean up temporary files
    Remove-Item $tempRulesFile -Force
    Remove-Item $tempParametersFile -Force
    Remove-Item $tempAssignmentParamsFile -Force
    
    Write-Host "✅ Custom policy created and assigned successfully" -ForegroundColor Green
}

Write-Host "================================================" -ForegroundColor Yellow

# Verify policy assignments
Write-Host "🔍 Verifying policy assignments..." -ForegroundColor Cyan
if ($UseBuiltInPolicies) {
    Write-Host "Windows Policy Assignment:" -ForegroundColor Yellow
    az policy assignment show --name "$PolicyAssignmentName-windows" --scope "/subscriptions/$SubscriptionId" --query "{name: name, displayName: displayName, policyDefinitionId: policyDefinitionId}" --output table
    
    Write-Host "`nLinux Policy Assignment:" -ForegroundColor Yellow
    az policy assignment show --name "$PolicyAssignmentName-linux" --scope "/subscriptions/$SubscriptionId" --query "{name: name, displayName: displayName, policyDefinitionId: policyDefinitionId}" --output table
} else {
    az policy assignment show --name $PolicyAssignmentName --scope "/subscriptions/$SubscriptionId" --query "{name: name, displayName: displayName, policyDefinitionId: policyDefinitionId}" --output table
}

Write-Host "`n📊 Checking initial compliance status..." -ForegroundColor Cyan
Write-Host "Note: It may take 5-10 minutes for compliance evaluation to complete." -ForegroundColor Yellow

# Create remediation tasks
Write-Host "`n🔧 Creating remediation tasks..." -ForegroundColor Cyan
if ($UseBuiltInPolicies) {
    Write-Host "Creating Windows remediation task..." -ForegroundColor Cyan
    az policy remediation create `
        --name "$PolicyAssignmentName-windows-remediation" `
        --policy-assignment "$PolicyAssignmentName-windows" `
        --scope "/subscriptions/$SubscriptionId" `
        --location-filters $Location
    
    Write-Host "Creating Linux remediation task..." -ForegroundColor Cyan
    az policy remediation create `
        --name "$PolicyAssignmentName-linux-remediation" `
        --policy-assignment "$PolicyAssignmentName-linux" `
        --scope "/subscriptions/$SubscriptionId" `
        --location-filters $Location
} else {
    az policy remediation create `
        --name "$PolicyAssignmentName-remediation" `
        --policy-assignment $PolicyAssignmentName `
        --scope "/subscriptions/$SubscriptionId" `
        --location-filters $Location
}

Write-Host "`n================================================" -ForegroundColor Yellow
Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "`n📋 Summary:" -ForegroundColor Cyan
Write-Host "  • Subscription: $SubscriptionId" -ForegroundColor White
Write-Host "  • DCR Resource ID: $dcrResourceId" -ForegroundColor White
Write-Host "  • Policy Type: $(if ($UseBuiltInPolicies) { 'Built-in Initiatives' } else { 'Custom Policy' })" -ForegroundColor White
Write-Host "  • Assignment Name(s): $(if ($UseBuiltInPolicies) { "$PolicyAssignmentName-windows, $PolicyAssignmentName-linux" } else { $PolicyAssignmentName })" -ForegroundColor White

Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Monitor policy compliance in Azure Portal > Policy > Compliance" -ForegroundColor White
Write-Host "  2. Check remediation task progress in Azure Portal > Policy > Remediation" -ForegroundColor White
Write-Host "  3. Verify DCR associations are created for Arc-enabled VMs" -ForegroundColor White
Write-Host "  4. Monitor data flow in your Log Analytics workspace" -ForegroundColor White

Write-Host "`n🔍 Useful commands:" -ForegroundColor Cyan
Write-Host "  # Check compliance status:" -ForegroundColor Yellow
if ($UseBuiltInPolicies) {
    Write-Host "  az policy state list --scope '/subscriptions/$SubscriptionId' --filter `"(policyAssignmentName eq '$PolicyAssignmentName-windows') or (policyAssignmentName eq '$PolicyAssignmentName-linux')`"" -ForegroundColor Gray
} else {
    Write-Host "  az policy state list --scope '/subscriptions/$SubscriptionId' --filter `"policyAssignmentName eq '$PolicyAssignmentName'`"" -ForegroundColor Gray
}

Write-Host "`n  # Check DCR associations:" -ForegroundColor Yellow
Write-Host "  az monitor data-collection rule association list --resource '/subscriptions/$SubscriptionId/resourceGroups/YOUR_RG/providers/Microsoft.HybridCompute/machines/YOUR_VM'" -ForegroundColor Gray

Write-Host "`n================================================" -ForegroundColor Yellow
Write-Host "✨ Script execution completed!" -ForegroundColor Green