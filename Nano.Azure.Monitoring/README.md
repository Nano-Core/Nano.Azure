# Nano.Azure.Monitoring

> _Centralized monitoring and logging for Nano infrastructure and applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
* **[Dependencies](#dependencies)**  

## Summary
Azure Log Analytics is a service that collects and analyzes log and performance data from various sources, providing insights through advanced querying and visualization. It uses 
a Log Analytics workspace as a central repository for storing and managing this data. The workspace supports powerful queries with Kusto Query Language (KQL) and integrates with 
other Azure services for comprehensive monitoring and troubleshooting.  

> 📖 Learn more about **[Azure Backup](https://learn.microsoft.com/azure/azure-monitor)**.

## Registration
Execute the `deploy.ps1` to create the log-analytics workspace and monitor group on Azure.  

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

This configuration routes all alerts to the `monitor-action-group` and sends notifications to members of the following roles.  

| Role                     | Type   | 
| ------------------------ | ------ |
| Monitoring Reader        | Email  |
| Monitoring Contributor   | Email  |

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

## Dependencies
Monitoring has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                           | Description                                                             | 
| -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Account/README.md#nanoazureaccount)**  | The is the foundation or prerequites of the Nano Azure infrastructure.  |
