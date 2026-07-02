# Nano.Azure.Monitoring

> _Centralized monitoring - metrics and logging for Nano infrastructure and applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Log Analytics Workspace](#log-analytics-workspace)**  
  * **[Monitor Workspace](#monitor-workspace)**  
  * **[Monitor Action Group](#monitor-action-group)**  
* **[Dependencies](#dependencies)**  

## Summary
Monitoring deploys the foundational resources required to enable monitoring across other Azure resources.  

Azure Log Analytics is a service that collects, stores, and analyzes log and performance data from a wide range of sources. A Log Analytics workspace acts as the central 
repository for this data, enabling powerful querying using Kusto Query Language (KQL), as well as integration with Azure Monitor and other Azure services. This provides a unified 
platform for monitoring, troubleshooting, and gaining operational insights across your environment.  

An Azure Monitor workspace is a dedicated environment for storing and managing data collected by Azure Monitor. Each workspace maintains its own data store, configuration, and 
access control, allowing you to isolate monitoring data per application, workload, or tenant while supporting scalable and flexible observability setups.  

Create a shared Log Analytics workspace to centralize logs and diagnostics across all Nano resources, alongside an Azure Monitor workspace aligned with modern monitoring practices 
and used for Prometheus-based metrics. An Azure Monitor Action Group is also provisioned to route and dispatch alerts from Azure resources.

To access the centralized logging for all resources, navigate to **[Azure Monitor](https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/overview)**.

#### Azure Monitoring Architecture
![Nano Azure Monitoring Architecture](https://raw.githubusercontent.com/Nano-Core/Nano.Azure/master/.assets/Nano-Monitoring.jpg)

> 📖 Learn more about **[Azure Log Analytics Workspace](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-workspace-overview)**.  
> 📖 Learn more about **[Azure Monitor Workspace](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/overview)**.  

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

### Log Analytics Workspace
Execute the next part of the `deploy.ps1` to create the log-analytics workspace.    

### Monitor Workspace
Proceed to create the Azure Monitor workspace, which serves as the modern, recommended workspace for collecting and managing monitoring data.

This will also create a managed resource group (`MA_nano-monitor-workspace...`) that contains the data collection rules and endpoints associated with the Azure Monitor workspace. 
This resource group is system-managed, cannot be modified or moved, and should be left as is.

### Monitor Action Group
Continue the script to create the Azure Monitor Action Group.  

This configuration ensures that all Nano alerts are routed through the `monitor-action-group`, with email notifications sent to members assigned to the specified roles

| Role                     | Type   | 
| ------------------------ | ------ |
| Monitoring Reader        | Email  |
| Monitoring Contributor   | Email  |

> 💡 This may be updated in the future to support more advanced or flexible configuration and notification scenarios.

## Dependencies
Monitoring has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                   | Description                                                             | 
| ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.Account](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Account/README.md#nanoazureaccount)**  | The is the foundation or prerequites of the Nano Azure infrastructure.  |
