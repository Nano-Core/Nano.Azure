# Nano.Azure.Monitoring

> _Centralized monitoring - metrics and logging for Nano infrastructure and applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Log Analytics Workspace](#log-analytics-workspace)**  
  * **[Monitor Group](#monitor-group)**  
* **[Dependencies](#dependencies)**  

## Summary
Azure Log Analytics is a service that collects and analyzes log and performance data from various sources, providing insights through advanced querying and visualization. It uses 
a Log Analytics workspace as a central repository for storing and managing this data. The workspace supports powerful queries with Kusto Query Language (KQL) and integrates with 
other Azure services for comprehensive monitoring and troubleshooting.  

Create a shared Log Analytics workspace for all Nano resources. A monitor action group is also provisioned for Azure resources to dispatch alerts.  

> 📖 Learn more about **[Azure Monitoring](https://learn.microsoft.com/azure/azure-monitor)**.

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

### Log Analytics Workspace
Execute the next part of the `deploy.ps1` to create the log-analytics workspace.    

### Monitor Workspace
Continue and create the monitor workspace. This is the newer workspace used for monitoring. 

This will also create the managed resource group `MA_nano-monitor-workspace-staging_northeurope_managed`, containing data connection rule and endpoint for the monitor workspace. This
cannot be changed or moved. Leave it.  

### Monitor Group
Continue in the script to create the monitor-group on Azure.  

This configuration routes all Nano alerts to the `monitor-action-group` and sends email notifications to members of the following roles.  

| Role                     | Type   | 
| ------------------------ | ------ |
| Monitoring Reader        | Email  |
| Monitoring Contributor   | Email  |

> 💡 This may be updated in the future to support more advanced or flexible configuration scenarios.

## Dependencies
Monitoring has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                           | Description                                                             | 
| -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Account/README.md#nanoazureaccount)**  | The is the foundation or prerequites of the Nano Azure infrastructure.  |
