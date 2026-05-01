# Nano.Azure.Backup

> _Centralized data backup and recovery for Nano._  

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Backup Vault](#backup-vault)**  
  * **[Diagnostics Settings](#diagnostics-settings)**  
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

### Backup Vault
Execute the next part of the `deploy.ps1` to create the backup vault on Azure.  

The default value is `LocallyRedundant`, where data is replicated within the same Azure region to protect against hardware failures. Other supported values are `GeoRedundant` and 
`ZoneRedundant`.

### Diagnostics Settings
Last, execute the final part of the script to configure diagnostics settings for the backup vault.  

The diagnostic settings for backup are configured to `AllMetrics`, and the time-grain is set tot 1-minute aggregation interval. This value can be adjusted if needed. You can 
retrieve the full list of supported metric categories for the backup resource using the following command.  

```powershell
az monitor diagnostic-settings categories list --resource $env:BACKUP_ID;
```

## Dependencies
Backup has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Account/README.md#nanoazureaccount)**                   | The is the foundation or prerequites of the Nano Azure infrastructure.  |
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging                       |
