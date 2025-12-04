# Data collection rules (DCRs) in Azure Monitor

Data collection rules (DCRs) are part of an [Extract, transform, and load (ETL)](/azure/architecture/data-guide/relational-data/etl)-like data collection process that improves on legacy data collection methods for Azure Monitor. This process uses a common data ingestion strategy for all data sources and a standard method of configuration that's more manageable and scalable than previous collection methods.

Specific advantages of DCR-based data collection include:

* Consistent method for configuration of different data sources.
* Ability to apply a transformation to filter or modify incoming data before it's sent to a destination.
* Scalable configuration options supporting infrastructure as code and DevOps processes.
* Option of Azure Monitor pipeline in your own environment to provide high-end scalability, layered network configurations, and periodic connectivity.

Use the following command to create a Data Collection Rule (DCR) and use the relevant JSON files for the service you want to enable metrics for.  The JSON files included in this repo contain the recommended baseline metrics for the particular Azure services you want to monitor, based on [Azure Monitor Baseline Alerts](https://azure.github.io/azure-monitor-baseline-alerts/welcome/) standards.

### [CLI](#tab/cli)

### Create or edit DCR with CLI

Use the # az monitor data-collection rule create # command to create a DCR from your JSON file. You can use this same command to update an existing DCR.

```azurecli
az monitor data-collection rule create --location '<rule_region>' --resource-group '<my-resource-group>' --name '<my-dcr-name>' --rule-file '<path_to_DCR_json_file' --description '<my-descriptive-name>'
```

## Data collection rule associations (DCRAs)

Data collection rule associations (DCRAs) are created between the resource and the DCR to enable certain data collection scenarios. This is a many-to-many relationship, where a single DCR can be associated with multiple resources and a single resource can be associated with up to 30 DCRs. This allows you to develop a strategy for maintaining your monitoring across sets of resources with different requirements.



