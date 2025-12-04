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


## Data collection rule associations (DCRAs)

Data collection rule associations (DCRAs) are created between the resource and the DCR to enable certain data collection scenarios. This is a many-to-many relationship, where a single DCR can be associated with multiple resources and a single resource can be associated with up to 30 DCRs. This allows you to develop a strategy for maintaining your monitoring across sets of resources with different requirements.

Using [Azure Policy](/azure/governance/policy/overview), you can associate a DCR with multiple resources at scale. When you create an assignment between a resource group and a built-in policy or initiative, associations are created between the DCR and each resource of the assigned type in the resource group, including any new resources as they're created. Azure Monitor provides a simplified user experience to create an assignment for a policy or initiative for a particular DCR, which is an alternate method to creating the assignment using Azure Policy directly.

> [!NOTE]
> A **policy** in Azure Policy is a single rule or condition that resources in Azure must comply with. For example, there's a built-in policy called **Configure Windows Machines to be associated with a Data Collection Rule or a Data Collection Endpoint**.
> 
> An **initiative** is a collection of policies that are grouped together to achieve a specific goal or purpose. For example, there's an initiative called **Configure Windows machines to run Azure Monitor Agent and associate them to a Data Collection Rule** that includes multiple policies to install and configure the Azure Monitor agent.

From the DCR in the Azure portal, select **Policies (Preview)**. This opens a page that lists any assignments with the current DCR and the compliance state of included resources. Tiles across the top provide compliance metrics for all resources and assignments.

:::image type="content" source="media/data-collection-rule-view/data-collection-rule-policies.png" alt-text="Screenshot of DCR policies view." lightbox="media/data-collection-rule-view/data-collection-rule-policies.png":::

To create a new assignment, click either **Assign Policy** or **Assign Initiative**. 

:::image type="content" source="media/data-collection-rule-view/data-collection-rule-new-policy.png" alt-text="Screenshot of new policy assignment blade." lightbox="media/data-collection-rule-view/data-collection-rule-new-policy.png":::

| Setting | Description |
|:--------|:------------|
| Subscription | The subscription with the resource group to use as the scope. |
| Resource group | The resource group to use as the scope. The DCR gets assigned to all resource in this resource group, depending on the resource group managed by the definition. |
| Policy/Initiative definition | The definition to assign. The dropdown includes all definitions in the subscription that accept DCR as a parameter. |
| Assignment Name | A name for the assignment. Must be unique in the subscription. |
| Description | Optional description of the assignment. |
| Policy Enforcement | The policy is only applied if enforcement is enabled. If disabled, only assessments for the policy are performed. |

Once an assignment is created, you can view its details by clicking on it. This allows you to edit the details of the assignment and also to create a remediation task.

:::image type="content" source="media/data-collection-rule-view/data-collection-rule-assignment-details.png" alt-text="Screenshot of assignment details." lightbox="media/data-collection-rule-view/data-collection-rule-assignment-details.png":::

> [!IMPORTANT]
> The assignment won't be applied to existing resources until you create a remediation task. For more information, see [Remediate noncompliant resources with Azure Policy](/azure/governance/policy/how-to/remediate-resources).
