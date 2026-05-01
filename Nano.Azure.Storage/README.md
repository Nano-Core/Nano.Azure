# Nano.Azure.Storage

> _Azure storage account file shares for Nano applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Storage Account](#storage-account)**  
  * **[Backup Policy](#backup-policy)**  
  * **[Alerts](#alerts)**  
  * **[Diagnostic Settings](#diagnostic-settings)**  
  * **[Network Rules](#network-rules)**  
* **[Dependencies](#dependencies)**  

## Summary
Azure Storage is a cloud service offering scalable and secure storage solutions for a variety of data types, including files, blobs, queues, and tables. It provides services such 
as Azure Blob Storage for unstructured data, Azure File Storage for managed file shares, and Azure Queue Storage for message queuing. With features like high availability, data 
redundancy, and advanced security, Azure Storage ensures that data is protected and accessible from anywhere.  

Create a Storage Account used to provision file shares for Nano applications.  

> 📖 Learn more about **[Azure Storage](https://learn.microsoft.com/azure/storage)**.

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

After successful registration, enable Defender directly on the Storage Account in the Azure Portal. This setting is not currently configurable via the Azure CLI.  

### Storage Account
Execute the next part of the `deploy.ps1` to create the storage account on Azure.  

Other available Storage SKUs.  

| SKU              | Description                       | Data redundancy & availability                                     | Typical use case                                       |
| ---------------- | --------------------------------- |------------------------------------------------------------------- | ------------------------------------------------------ |
| Standard_LRS     | Locally Redundant Storage         | 3 copies of data within a single datacenter in a region.           | Lowest cost, non-critical data, dev/test.              |
| Standard_ZRS     | Zone Redundant Storage            | 3 copies across multiple availability zones in the same region.    | Higher availability, protection against zone failure.  |
| Standard_GRS     | Geo-Redundant Storage             | LRS in primary region + async replication to a secondary region.   | Disaster recovery, read/write in primary only.         |
| Standard_RAGRS   | Read-Access Geo-Redundant Storage | GRS + read access to secondary region.                             | Disaster recovery with read-only secondary access.     |

To retrieve a clean and relevant list of available Storage SKUs for a specific region, use the following command.  

```powershell
az storage sku list --query "[?kind=='StorageV2' && contains(locations, '$env:AZURE_LOCATION')].[name, tier]" -o table
```

Create the storage account secrets in GitHub. These will be used later to mount storage account file shares into applications. Run the command below to retrieve the access 
key for the newly created storage account.  

```powershell
az storage account keys list --account-name $env:APP_NAME --resource-group $env:AZURE_RESOURCE_GROUP --query "[].value" -o tsv;
```

| Secret                                       | Type     | Description                                                      |
| -------------------------------------------- | -------- | ---------------------------------------------------------------- |
| `{{environment}}_STORAGE_CREDENTIALS_ID`     | Secrets  | The name of the storage account.                                 |
| `{{environment}}_STORAGE_CREDENTIALS_SECRET` | Secrets  | The account key used to authenticate with the storage account.   |

### Backup Policy
Continue the script by registering the backup policy for the storage account.  

The backup policy runs daily and weekly on Sundays at 04:30 UTC and uses **[Nano.Azure.Backup](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Backup/README.md#nanoazurebackup)** 
to store file share backups. Daily backups are retained for 30 days, while weekly backups are retained for 24 weeks. These retention settings can be adjusted to meet specific 
requirements. The policy can be configured either through the Azure portal or by using a JSON definition similar to the one provided here.  

## Alerts
Last, create the defailt alerts.  

The alerts have been configured for the storage account and are associated with the action group created in 
**[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**. These alerts monitor low availability, 
high latency, elevated egress traffic, and excessive transaction counts.  

### Diagnostic Settings
Next, create the diagnostic settings for the storage account.  

The diagnostic settings for storage includes both `Capacity` and `Transaction`, and the time-grain is set tot 1-minute aggregation interval. This value can be adjusted if needed. 
You can retrieve the full list of supported metric categories for the storage resource using the following command.  

```powershell
az monitor diagnostic-settings categories list --resource $env:STORAGE_ACCOUNT_ID;
```

## Network Rules
The storage account has no public access by default. 

Optionally, IP address whitelisting can be configured to allow access to the storage file shares. By default, access is fully restricted, and no external connections are permitted. 
The Nano system does not depend on IP whitelisting for connectivity, and using it is generally discouraged as it can negatively impact the overall cloud security score. If IP 
whitelisting is required, it can be configured using the following command.  

```powershell
$env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS = "";

az storage account network-rule add `
    -n $env:APP_NAME `
    --ip-address $env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS;
```

## Dependencies
Storage has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Account/README.md#nanoazureaccount)**                   | The is the foundation or prerequites of the Nano Azure infrastructure.  |
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging.                      |
| **[Nano.Azure.Backup](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Backup/README.md#nanoazurebackup)**              | Backup and recovery services.                                           |
