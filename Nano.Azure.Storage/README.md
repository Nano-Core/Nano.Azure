# Nano.Azure.Storage

> _Azure storage account file shares for Nano applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Storage Account](#storage-account)**  
  * **[Managed Identity](#managed-identity)**  
  * **[Soft Delete](#soft-delete)**  
  * **[Backup Policy](#backup-policy)**  
  * **[Alerts](#alerts)**  
  * **[Diagnostic Settings](#diagnostic-settings)**  
  * **[Network Rules](#network-rules)**  
  * **[Microsoft Defender](#microsoft-defender)**  
* **[Dependencies](#dependencies)**  

## Summary
Azure Storage is a cloud service offering scalable and secure storage solutions for a variety of data types, including files, blobs, queues, and tables. It provides services such 
as Azure Blob Storage for unstructured data, Azure File Storage for managed file shares, and Azure Queue Storage for message queuing. With features like high availability, data 
redundancy, and advanced security, Azure Storage ensures that data is protected and accessible from anywhere.  

Create a storage account to host and provision Azure File Shares for Nano applications.  

#### Azure Storage Architecture
![Nano Azure Storage Architecture](https://raw.githubusercontent.com/Nano-Core/Nano.Azure/master/.assets/Nano-Storage.jpg)

> 📖 Learn more about **[Azure Storage](https://learn.microsoft.com/azure/storage)**.

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

Add the resource group name as GitHub organization variables.  

| Secret                          | Type    | Description                                       |
| ------------------------------- | ------- |-------------------------------------------------- |
| `AZURE_RESOURCE_GROUP_STORAGE`  | vars    | The Azure resource group of the storage account.  |

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
$env:AZURE_LOCATION_ID = ($env:AZURE_LOCATION -replace '\s+', '').ToLower();

az storage sku list --query "[?kind=='StorageV2' && contains(locations, '$env:AZURE_LOCATION_ID')].[name, tier]" -o table
```

> ⚠️ Finding a compatible `--kind` and `--sku` combination for the selected region can sometimes be challenging due to SKU availability and regional support limitations.  

In addition to the Azure storage account setup, the required Kubernetes `storageClass` resource is also created.  

### Managed Identity
Shared key access is also disabled (`--allow-shared-key-access false`), preventing authentication through storage account access keys. As a result, access to the storage account must use 
Microsoft Entra ID–based authentication and Azure role-based access control (RBAC), reducing the risk associated with long-lived shared secrets and supporting a more secure, identity-based 
access model.  

> ⚠️ Executing the script requires User Access Administrator on the subscription.

Kubernetes requires a secure way to authenticate and access the Azure File Shares mounted into the application containers. This configuration uses a managed identity together with workload 
identity federation, allowing pods in the cluster to access the storage account without relying on storage account keys or connection strings. Applications themselves are responsible for 
linking the managed identity to a Kubernetes service account through the cluster's OIDC issuer.

This ensures secure, keyless access to the file shares while keeping authentication fully managed through Microsoft Entra ID.

The service principal used for deployments is responsible for provisioning managed identities for applications and granting them access to Azure Storage. It is granted 
`Restricted User Access Administrator (Storage)`, a custom role that grants `Microsoft.Authorization/roleAssignments/write`, restricted by condition to only allow assigning the 
`Storage File Data SMB Share Contributor` role, and only to principals of type `ServicePrincipal`.

> ⚠️ The permissions will trigger a Defender (low) finding: _Service Principals should not be assigned with administrative roles at the subscription and resource group level._

### Soft Delete
Enables soft delete for blobs, containers, and file shares with a 7-day retention period, allowing recovery of accidentally deleted data.  

### Backup Policy
Continue the script by registering the backup policy for the storage account.  

The backup policy is scheduled daily at 04:00 UTC and uses **[Nano.Azure.Backup](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Backup/README.md#nanoazurebackup)** to 
store file share backups. Daily backups are retained for 30 days. These retention settings can be adjusted to meet specific requirements. The policy can be configured either through the 
Azure portal or by using a JSON definition similar to the one provided here.  

The concrete file shares still needs to enable backup when created. Also, Azure File Shares protected by Azure Backup cannot be deleted while backup is enabled or recovery points exist. 
When backup is configured, Azure may also apply a management lock (AzureBackupProtectionLock) on the storage account to prevent accidental deletion of protected data. This lock must be 
removed before the storage account or file share can be deleted.  

To inspect or remove the lock from the storage account.

```powershell
az lock list --resource $env:STORAGE_ACCOUNT_ID;

az lock delete --name AzureBackupProtectionLock --resource $env:STORAGE_ACCOUNT_ID;
```

## Alerts
Next, create the default alert rules to ensure baseline monitoring and early detection of common issues across the storage account.  

The alerts have been configured for the storage account and are associated with the action group created in 
**[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**. These alerts monitor low availability, 
high latency, elevated egress traffic, and excessive transaction counts.  

### Diagnostic Settings
Proceed with configuring diagnostic settings for the storage account to enable logging and monitoring of its activity and performance.

The diagnostic settings for backup metrics are configured to both `Capacity` and `Transaction` with a 1-minute aggregation interval, which can be adjusted if required. This ensures 
high-resolution monitoring of backup performance data. Diagnostics settings are also configured for file shares for both metrics and logs. The full list of supported metric and log 
categories for the storage account resource can be retrieved using the following command.  

```powershell
az monitor diagnostic-settings categories list --resource $env:STORAGE_ACCOUNT_ID;
```

## Network Rules
The storage account is configured with public network access disabled (`--public-network-access Disabled`), ensuring that all access to storage services is restricted to private 
network connectivity through approved virtual networks and private endpoints. This prevents exposure of the storage account to the public internet and strengthens the overall network 
security posture.  

A Private Endpoint is created within the Kubernetes virtual network, enabling applications running in the cluster to securely access the Storage Account file shares over a private 
connection. Nano defaults to creating a Private Endpoint for the file shares component of the storage account by using `--group-id file`.

To list the available `--group-id` values for use with the `az network private-endpoint create` command, run the following command.  

```powershell
az network private-link-resource list --id $env:STORAGE_ACCOUNT_ID;
```

> ⚠️ The private endpoint must be deployed in the same Azure region as the virtual network (VNet) it is associated with.

Optionally, IP address whitelisting can be configured to allow access to the storage file shares. By default, access is fully restricted, and no external connections are permitted. 
The Nano system does not depend on IP whitelisting for connectivity, and using it is generally discouraged as it can negatively impact the overall cloud security score. If IP 
whitelisting is required, it can be configured using the following command.  

```powershell
$env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS = "";

az storage account network-rule add `
    -n $env:APP_NAME `
    --ip-address $env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS;
```

> ⚠️ Whitelisting IP addresses can reduce the overall security posture and negatively impact the security score.  

### Microsoft Defender
After successful registration, enable Microsoft Defender either directly on the storage resource or via the Defender for Cloud overview in the Azure Portal.  

> ⚠️ This setting is not currently configurable via the Azure CLI.  

## Dependencies
Storage has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging.                      |
| **[Nano.Azure.Backup](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Backup/README.md#nanoazurebackup)**              | Backup and recovery services.                                           |
| **[Nano.Azure.Kubernetes](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Kubernetes/README.md#nanoazurekubernetes)**  | The Azure Kubernetes Service (AKS).                                           |
