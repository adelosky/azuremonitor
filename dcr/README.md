# Data collection rules (DCRs) in Azure Monitor

Data collection rules (DCRs) are part of an [Extract, transform, and load (ETL)](/azure/architecture/data-guide/relational-data/etl)-like data collection process that improves on legacy data collection methods for Azure Monitor. This process uses a common data ingestion strategy for all data sources and a standard method of configuration that's more manageable and scalable than previous collection methods.

Specific advantages of DCR-based data collection include:

* Consistent method for configuration of different data sources.
* Ability to apply a transformation to filter or modify incoming data before it's sent to a destination.
* Scalable configuration options supporting infrastructure as code and DevOps processes.
* Option of Azure Monitor pipeline in your own environment to provide high-end scalability, layered network configurations, and periodic connectivity.

Use the following command to create a Data Collection Rule (DCR) and use the relevant JSON files for the service you want to enable metrics for.  The JSON files included in this repo contain the recommended baseline metrics for the particular Azure services you want to monitor, based on [Azure Monitor Baseline Alerts](https://azure.github.io/azure-monitor-baseline-alerts/welcome/) standards.

### Create or edit DCR with CLI

Use the _az monitor data-collection rule create_ command to create a DCR from your JSON file. You can use this same command to update an existing DCR.

```azurecli
az monitor data-collection rule create --location '<rule_region>' --resource-group '<my-resource-group>' --name '<my-dcr-name>' --rule-file '<path_to_DCR_json_file' --description '<my-descriptive-name>'
```


# Data collection rule associations (DCRAs)

Data collection rule associations (DCRAs) are created between the resource and the DCR to enable certain data collection scenarios. This is a many-to-many relationship, where a single DCR can be associated with multiple resources and a single resource can be associated with up to 30 DCRs. This allows you to develop a strategy for maintaining your monitoring across sets of resources with different requirements.

Using [Azure Policy](/azure/governance/policy/overview), you can associate a DCR with multiple resources at scale. When you create an assignment between a resource group and a built-in policy or initiative, associations are created between the DCR and each resource of the assigned type in the resource group, including any new resources as they're created. Azure Monitor provides a simplified user experience to create an assignment for a policy or initiative for a particular DCR, which is an alternate method to creating the assignment using Azure Policy directly.

> [!NOTE]
> A **policy** in Azure Policy is a single rule or condition that resources in Azure must comply with. For example, there's a built-in policy called **Configure Windows Machines to be associated with a Data Collection Rule or a Data Collection Endpoint**.
> 
> An **initiative** is a collection of policies that are grouped together to achieve a specific goal or purpose. For example, there's an initiative called **Configure Windows machines to run Azure Monitor Agent and associate them to a Data Collection Rule** that includes multiple policies to install and configure the Azure Monitor agent.


### Create a DCRA through Azure Policy with CLI

1. First, ensure you have the necessary Data Collection Rule (DCR) resource ID:
```azurecli
# Get the DCR resource ID
$dcrResourceId = az monitor data-collection rule show `
    --resource-group "your-resource-group" `
    --data-collection-rule-name "your-dcr-name" `
    --query "id" `
    --output tsv
```
2. Use the built in policy initiatives to associate Windows Arc-enabled servers to the DCR:
```azurecli
az policy assignment create `
    --name "configure-windows-arc-dcr" `
    --display-name "Configure Windows Arc-enabled machines with DCR" `
    --policy-set-definition "9575b8b7-78ab-4281-b53b-d3c1ace2260b" `
    --scope "/subscriptions/$subscriptionId" `
    --params "{\"dataCollectionRuleResourceId\": {\"value\": \"$dcrResourceId\"}}" `
    --mi-system-assigned `
    --location "<your-region>"
```
3. Verify policy assignments.
```azurecli
# Check policy assignment
az policy assignment show `
    --name "arc-dcr-assignment" `
    --scope "/subscriptions/$subscriptionId"

# Check compliance status
az policy state list `
    --scope "/subscriptions/$subscriptionId" `
    --filter "(isCompliant eq false) and (policyAssignmentName eq 'arc-dcr-assignment')"
```
4. Trigger remediation (if needed):
```azurecli
# Create remediation task for non-compliant resources
az policy remediation create `
    --name "arc-dcr-remediation" `
    --policy-assignment "arc-dcr-assignment" `
    --scope "/subscriptions/$subscriptionId"
```


> [!IMPORTANT]
> The policy assignment uses system-assigned managed identity for deployment permissions.
>
> The policy is assigned at subscription level but can be scoped to resource groups.

