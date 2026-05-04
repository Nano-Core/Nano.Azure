# Nano.Azure.Kubernetes

> _Azure Kubernetes Service (AKS) deployment for Nano applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Kubernetes Cluster](#kubernetes-cluster)**  
  * **[Auto Upgrade](#auto-upgrade)**  
  * **[Auto Scaling](#auto-scaling)**  
  * **[Network Policy](#network-policy)**  
  * **[Maintenance](#maintenance)**  
  * **[Monitoring](#monitoring)**  
  * **[Alerts](#alerts)**  
  * **[Policy](#policy)**  
  * **[Microsoft Defender](#defender)**  
  * **[Image Cleaner](#image-cleaner)**  
  * **[Diagnostic Settings](#diagnostic-settings)**  
  * **[Network Rules](#network-rules)**  
  * **[VPN Gateway](#vpn-gateway)**  
  * **[System Nodepool](#system-nodepool)**  
  * **[GPU Nodepool](#gpu-Nodepool)**  
  * **[Backup](#backup)**  
* **[Kubernetes Container Registry Access](#kubernetes-container-registry-access)**  
* **[Scaling Formula](#scaling-formula)**  
* **[Dependencies](#dependencies)**  
* **[`kubectl` Commands](#kubectl-commands)**  

## Summary
Azure Kubernetes Service (AKS) is a managed Kubernetes service that simplifies the deployment and operation of Kubernetes clusters. AKS automates tasks such as provisioning, 
scaling, and upgrading clusters, reducing the operational burden on teams. It supports both Linux and Windows containers and provides built-in monitoring and security features. 
AKS allows for easy scaling of applications and ensures high availability, making it ideal for running containerized workloads in production environments.  

Create a Kubernetes Cluster (AKS) to orchestrate Nano infrastructure components and applications.    

> 📖 Learn more about **[Azure Kubernetes (AKS)](https://learn.microsoft.com/en-us/azure/aks)**.

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

When done registering the cluster, sign in using the following command.  

```powershell
az aks get-credentials -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME
```

### Kubernetes Cluster
Execute the next part of the `deploy.ps1` to create a managed Kubernetes cluster (AKS) on Azure.  

The SLA tier is set to `standard`, enabling Azure's standard managed cluster service with a financially backed SLA. Other values are: `free` and `premium`.  

The available Kubernetes versions in a specific region can also be queried, by this command.  

```powershell
az aks get-versions -l $env:AZURE_LOCATION --output table;
```

The default nodepool SKU is set to: `standard_d4as_v7`, but other SKUs can also be used depending on workload requirements and the Azure region. To see all available SKUs for 
a specific region use the command below.  

```powershell
az vm list-skus -l $env:AZURE_LOCATION --query "[?resourceType=='virtualMachines'].[name, tier]" -o table     # commmand is a bit slow have patience.
```

> ⚠️ For production-grade Azure Kubernetes Service (AKS) clusters, a minimum of three nodes is recommended, each with at least four vCPUs.

Create the required secrets in GitHub for the Kubernetes cluster.    

| Secret                                   | Type     | Description                                           |
| ---------------------------------------- | -------- | ----------------------------------------------------- |
| `AZURE_KUBERNETES_RESOURCE_GROUP`        | vars     | The Azure resource group of the Kubernetes cluster.   |
| `{{environment}}_KUBERNETES_CLUSTER`     | vars     | The name of the Kubernets cluster.                    |

### Auto Upgrade
    --node-os-upgrade-channel NodeImage `
    --auto-upgrade-channel patch `

### Auto Scaling 
    --enable-cluster-autoscaler `
    --max-count $env:KUBERNETES_NODES_MAX `
    --min-count $env:KUBERNETES_NODES_MIN `
Keda Scaling, more advanced and configurable scaling options.

### Network Policy
    --network-plugin azure `
    --network-plugin-mode=overlay `
    --network-policy azure `

### Maintenance
Is set to sunday at 04:00 UTC, but can be any time a week.

> ⚠️ Be aware that the portal doesn't show the default schedule but only if the different update controls schedules are setup separately.

### Monitoring
Enable monitoring using either Azure or Prometheus with Grafana. 

Container insights collects stdout/stderr logs, performance metrics, and Kubernetes events from each node in your cluster. It provides dashboards and reports for analyzing this data, including the availability of your nodes and other components. Use Log Analytics to identify any availability errors in your collected logs.

The data collection rule for collection logs and metrics is a pretty decent production-grade configuration. For dev/test environments, this can be modified to save costs.
The argument may also be omitted to use Azure default configuration. This can be modified later on if needs changes.
Use Log Analytics Workspace

Enable Prometheus on your cluster with Azure Monitor managed service for Prometheus if you don't already have a Prometheus environment. Use Azure Managed Grafana to analyze the collected Prometheus data. See Customize scraping of Prometheus metrics in Azure Monitor managed service for Prometheus to collect additional metrics beyond the default configuration.
Azure will create a bunch of collection rules, which takes care of ingrsting the Kubernetes metrics and logs into the Monitor Workspace.
Uses Monitor Workspace.

> 📖 Learn more about **[Azure Monitoring](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable)**.

### Alerts
Legacy alerts are not as precise. for example we can't measure that a pod exceeds 80% of its limit. Only container 80% which is fixed 800 mCPU.
Prometheus can detect real 80% of a pod

TABLE over alerts for both Prometheus and Container insight

### Policy
Adds the default azure compliance policy. 
[Azure Policy](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade.MenuView/~/Overview)

### Microsoft Defender
The log-analytics workspace created with [Nano.Azure.Monitoring]() is connected to the Kubernetes cluster as well as the Defender configuration.
    --enable-defender `
    --defender-config=$env:DEFENDER_CONFIG_FILE_PATH `

### Image Cleaner
    --enable-image-cleaner `
    --image-cleaner-interval-hours 24 `

### Diagnostic Settings
Next, create the diagnostic settings for the Kuberentes cluster.  

The diagnostic settings for MySQL includes both `AllMetrics` for metrics, and `MySqlSlowLogs` and `MySqlAuditLogs`, and the time-grain is set tot 1-minute aggregation interval. This 
value can be adjusted if needed. You can retrieve the full list of supported metric categories for the MySQL resource using the following command.  

```powershell
az monitor diagnostic-settings categories list --resource $env:KUBERNETES_ID;
```

and for the load balancer. 

```powershell
az monitor diagnostic-settings categories list --resource $env:LOAD_BALANCER_ID;
```

### Network Rules
The Kubernetes Cluster has no public access by default. 

Optionally, IP address whitelisting can be configured to allow access to the storage file shares. By default, access is fully restricted, and no external connections are permitted. 
The Nano system does not depend on IP whitelisting for connectivity, and using it is generally discouraged as it can negatively impact the overall cloud security score. If IP 
whitelisting is required, it can be configured using the following command.  

```powershell
$env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS = "";

az aks updaate `
    -g $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION `
    -n $env:APP_NAME `
    --api-server-authorized-ip-ranges $env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS;
```

### VPN Gateway
VNET_ADDRESS_PREFIXES should be a ip-range space outside of already allocated ranges from other subnets.

Download Azure VPN Client from the Microsoft Store or similar if not using Windows. https://apps.microsoft.com/detail/9np355qt2sqb
Run the following command to get a donwload link for the VPN client configuration. 

```powershell
az network vnet-gateway vpn-client generate `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n $env:VNET_GATEWAY_NAME;
```

To find available IP ranges in the VNET of the Kubernetes cluster, use the following commands:

```powershell
az network vnet show -g $env:AZURE_RESOURCE_GROUP_ASSETS -n $env:VNET_NAME --query addressSpace.addressPrefixes;

az network vnet subnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --vnet-name $env:VNET_NAME --query "[].{Name:name,Prefix:addressPrefix}" -o table
```

### System Nodepool

### GPU Nodepool

### Backup
Backup has not been configured for the AKS Kubernetes cluster. THe whole setup reiles on empheral setup, and critical data is stored in managed services outside Kubernetes.
Enabling Kubernetes backup requires a private endpoints setup between Kubernetes VNET and the Backup Vault.


## Kubernetes Container Registry Access
Last, excute the `cr-pull-secret.ps1`, needed for Kubernetes to have permission to pull images from the container registry.  

## Scaling Formula
When defining the scaling for _Horizontal Pod Auto-scaler (HPA)_, Kubernetes uses the _Resource Request_ as the base for calculating when to scale. Since what we actually want 
is to scale when we are reaching the _Resource Limit_. The formula below calculates the resource utilization in percentage, that should be used when defining the HPA.

The formula: `Pod Resource Limit(L) x Desired Scale percentage(P) / Pod Resource Request(R) * 100 = HPA Average Utilization`  
Example: `2.100 * 80% / 700 * 100 = 240`

## Dependencies
Kubernetes has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Account/README.md#nanoazureaccount)**                   | The is the foundation or prerequites of the Nano Azure infrastructure.  |
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging.                      |
| **[Nano.Azure.Storage](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Storage/README.md#nanoazurestorage)**           | Storage account and fileshares.                                         |

## `Kubectl` commands
az aks get-credentials -g Nano-Kubernetes -n live-cluster

kubectl top nodes
kubectl events --namespace={{namespace}} --field-selector InvolvedObject.Name={{pod-name}}
kubectl logs -l app={{app}} --tail=-1 | findstr -i '{{search}}'
kubectl patch cronjob {{cronjob-name}} -p '{"spec": {"suspend": true}}'
kubectl create job --from=cronjob/{{cronjob-name}} {{job-name}}
