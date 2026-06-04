# Nano.Azure.Backup

> _Centralized data backup and recovery for Nano._  

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Backup Vault](#backup-vault)**  
  * **[Data Redundancy](#data-redundancy)**  
  * **[Immutability State](#immutability-state)**  
  * **[Diagnostics Settings](#diagnostics-settings)**  
  * **[Alerts](#alerts)**  
* **[Dependencies](#dependencies)**  

## Summary
Azure Backup Vault is a cloud-based service that securely stores backup data for Azure resources like virtual machines, storage accounts, databases, and more. It provides 
centralized management, automated backup scheduling, and encryption for data protection. With flexible retention policies, it supports efficient disaster recovery and ensures 
your data is protected and recoverable in the event of a failure or loss.  

Create a Backup Vault used for file share and database backups, as well as other backup-enabled resources.  

> 📖 Learn more about **[Azure Backup](https://learn.microsoft.com/azure/backup)**.

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

Add the resource group name as GitHub organization variables.  

| Secret                          | Type    | Description                                    |
| ------------------------------- | ------- |----------------------------------------------- |
| `AZURE_RESOURCE_GROUP_BACKUP`   | vars    | The Azure resource group of the backup vault.  |

### Backup Vault
Execute the next part of the `deploy.ps1` to create the backup vault on Azure.  

By default, the Backup Vault is configured with `--soft-delete-feature-state` enabled and `--soft-delete-duration` set to 14 days. Use `az backup vault backup-properties set` to 
customize these settings. This also means that backup items created from protected Azure resources can prevent the vault from being deleted until the configured soft-delete 
retention period has expired or the source has been unregistered.

### Data Redundancy
The `--backup-storage-redundancy` parameter defines how backup data is replicated for durability. In this case, it is set to `ZoneRedundant`, meaning data is replicated across 
multiple availability zones within the same region to protect against zonal failures. Other options are `LocallyRedundant`, which stores copies within a single region, and 
`GeoRedundant`, which replicates data to a secondary region for broader disaster recovery protection.  

### Immutability State
By default, immutability is set to `Unlocked`, meaning it is enabled but can still be modified or disabled at a later stage. It is recommended to set the value to `Locked`. In 
`Locked` mode, immutability is permanently enforced and cannot be reversed, ensuring that backup data is protected against deletion or modification for the configured 
retention period.  

### Diagnostics Settings
Next, execute the script section that configures diagnostic settings for the backup vault.  

The diagnostic settings for backup metrics are configured to `AllMetrics` with a 1-minute aggregation interval, which can be adjusted if required. This ensures high-resolution 
monitoring of backup performance data. The logs configuration includes all Backup-related logs, while Site Recovery logs are excluded as they are not used by Nano. The full list 
of supported metric categories for the backup resource can be retrieved using the following command.  

```powershell
az monitor diagnostic-settings categories list --resource $env:BACKUP_ID;
```

### Alerts
The alerts used are the default Azure Backup alerts.  

An Alert Processing Rule is configured to route these alert notifications through the Action Group created as part of
**[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**.  

## Dependencies
Backup has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging                       |
