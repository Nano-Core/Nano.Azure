# Nano.Azure.Delivery

> _Delivery infrastructure for GitHub Self-Hosted Runners._  

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Kubernetes VNet Integration](#kubernetes-vnet-integration)**  
  * **[Log Analytics](#log-analytics)**  
* **[Dependencies](#dependencies)**  

## Summary
This script provisions the foundational Azure infrastructure required to run GitHub Actions self-hosted runners in a secure, isolated, and scalable environment. It sets up the required 
Azure resource groups, networking components, and monitoring services, including a dedicated virtual network subnet for Azure Container Apps and integration with Log Analytics for 
centralized observability.  

Finally, it creates an Azure Container Apps Environment configured for internal-only access and zone redundancy, providing a hardened and reliable execution layer for GitHub-based 
CI/CD workloads.  

#### Azure Architecture
![Nano Kubernetes Architecture](https://raw.githubusercontent.com/Nano-Core/Nano.Azure/v10.0.0-ga/.assets/Nano-Delivery.jpg)

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

Add the resource group name as GitHub organization variables.  

| Secret                           | Type    | Description                         |
| -------------------------------- | ------- |------------------------------------ |
| `AZURE_RESOURCE_GROUP_DELIVERY`  | vars    | The Delivery Azure resource group.  |

Continue with the `deploy.ps1` script.

### Kubernetes VNet Integration
The Azure Container Apps Environment is deployed into a dedicated subnet within an existing Virtual Network. This is required when the underlying Kubernetes cluster (AKS) is private 
and not publicly accessible. By delegating a dedicated subnet to Container Apps, we ensure secure network-level isolation and enable controlled communication between the runner 
infrastructure and the private AKS cluster.  

This design avoids public exposure while maintaining full internal connectivity within the delivery platform.

### Log Analytics
The Container Apps Environment is configured to use Log Analytics as its logging destination. By providing the workspace ID and shared key, all runtime logs, platform events, and 
diagnostics are streamed to a centralized Log Analytics workspace.  

This enables consistent observability across the delivery platform and simplifies monitoring, troubleshooting, and auditability of the self-hosted runner infrastructure.  

## Dependencies
Delivery has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging.                      |
| **[Nano.Azure.Kubernetes](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Kubernetes/README.md#nanoazurekubernetes)**  | The Azure Kubernetes Service (AKS).                                           |
