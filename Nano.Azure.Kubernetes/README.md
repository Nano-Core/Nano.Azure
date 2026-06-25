# Nano.Azure.Kubernetes

> _Azure Kubernetes Service (AKS) deployment for Nano applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Kubernetes Cluster](#kubernetes-cluster)**  
  * **[Apps Namespace](#apps-namespace)**  
  * **[Gateway Load Balancer](#gateway-load-balancer)**  
  * **[Automatic Upgrades](#automatic-upgrades)**  
  * **[Node Scaling](#node-scaling)**  
  * **[Network Policy](#network-policy)**  
  * **[Private API Server](#private-api-server)**  
  * **[DNS Resolver](#dns-resolver)**  
  * **[VPN Gateway](#vpn-gateway)**  
  * **[System Nodepool](#system-nodepool)**  
  * **[GPU Nodepool](#gpu-Nodepool)**  
  * **[Maintenance Window](#maintenance-window)**  
  * **[Monitoring](#monitoring)**  
  * **[Alerts](#alerts)**  
  * **[Site Recovery](#site-recovery)**  
  * **[Image Cleaner](#image-cleaner)**  
  * **[Diagnostic Settings](#diagnostic-settings)**  
  * **[Network Rules](#network-rules)**  
  * **[Microsoft Defender](#m,icrosoft-defender)**  
  * **[Azure Policy](#azure-policy)**  
* **[Get `kubectl` Credentials](#get-kubectl-credentials)**  
* **[Common `kubectl` Commands](#common-kubectl-commands)**
* **[Dependencies](#dependencies)**  

## Summary
Azure Kubernetes Service (AKS) is a managed Kubernetes service that simplifies the deployment and operation of Kubernetes clusters. AKS automates tasks such as provisioning, 
scaling, and upgrading clusters, reducing the operational burden on teams. It supports both Linux and Windows containers and provides built-in monitoring and security features. 
AKS allows for easy scaling of applications and ensures high availability, making it ideal for running containerized workloads in production environments.  

Create an Azure Kubernetes Service (AKS) cluster to orchestrate Nano infrastructure components and deploy applications.  

#### Azure Architecture
![Nano Kubernetes Architecture](https://raw.githubusercontent.com/Nano-Core/Nano.Azure/v10.0.0-ga/.assets/Nano-Kubernetes.jpg)

> 📖 Learn more about **[Azure Kubernetes (AKS)](https://learn.microsoft.com/en-us/azure/aks)**.

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

Add the following GitHub organization variables.  

| Secret                                    | Type    | Description                                                        |
| ----------------------------------------- | ------- |------------------------------------------------------------------- |
| `AZURE_RESOURCE_GROUP_KUBERNETES`         | vars    | The Azure resource group of the Kubernetes cluster (AKS).          |
| `AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS`  | vars    | The Azure resource group of the Kubernetes cluster (AKS) Asserts.  |
| `KUBERNETES_NAMESPACE`                    | vars     | The Kubernetes namespace to use for all deployments.              |

### Kubernetes Cluster
Execute the next part of the `deploy.ps1` to create a managed Kubernetes cluster (AKS) on Azure.  

The SLA tier is set to `standard`, enabling Azure's standard managed cluster service with a financially backed SLA. Other values are: `free` and `premium`.  

The available Kubernetes versions in a specific region can also be queried, by this command.  

```powershell
az aks get-versions -l $env:AZURE_LOCATION --output table;
```

Other node pool SKUs are available and can be selected based on workload requirements and regional availability in Azure. To view all supported SKUs for a specific region, use the 
following command.  

```powershell
az vm list-skus -l $env:AZURE_LOCATION --query "[?resourceType=='virtualMachines'].[name, tier]" -o table;
```

> ⚠️ For production-grade Azure Kubernetes Service (AKS) clusters, a minimum of three nodes is recommended, each with at least four vCPUs.

### Apps Namespace
This step creates the default Kubernetes namespace used by all Nano applications and components. It provides a consistent isolation boundary and ensures Gateway API resources, 
services, and supporting objects such as secrets and config maps are grouped together, reducing permission complexity and configuration overhead.  

It is created during cluster bootstrap and is safe to reapply in CI/CD pipelines. All application resources should target this namespace unless a specific multi-namespace design 
is explicitly required.  

Execute the `namespace.ps1` script to create the Kubernetes namespace.  

### Gateway Load Balancer
Application Gateway API support is enabled in the AKS cluster through `--enable-gateway-api`, adding the Kubernetes Gateway API custom resource definitions (CRDs) required for 
defining `Gateway`, `HTTPRoute`, and related networking resources. This introduces a modern Kubernetes-native traffic management model that replaces traditional Ingress-based 
routing with a more flexible and extensible API.  

Together with `--enable-application-load-balancer`, AKS deploys and configures the Azure Application Load Balancer (ALB) Controller within the cluster. The controller extends the 
cluster with the custom resource definitions (CRDs) required for managing `ApplicationLoadBalancer` resources and integrates Kubernetes Gateway API resources with Azure Application 
Gateway for Containers.  

> ⚠️ Make sure to choose a region that supports Azure Application Gateway for Containers. See **[Supported Regions](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/overview#supported-regions)**.

A separate subnet is created for the Azure Application Load Balancer, and the proper role assignments created for the load balancer to have the proper network permissions.  

> 📖 Learn more about how to **[Deploy Application Gateway for Containers ALB Controller using AKS Add-on](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon)**.  
> 📖 Learn more about how to **[Create Application Gateway for Containers managed by ALB Controller](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-managed-by-alb-controller)**.  

Finally, the Kubernetes resource is deployed in the cluster, which triggers the creation of the Azure Application Load Balancer resource. The Application Load Balancer provides the 
Azure-managed traffic distribution layer for Kubernetes ingress, routing external traffic into the cluster through the configured subnet and integrating with the Gateway API for 
application-level routing.  

This resource is managed by Azure and forms the foundation for inbound connectivity.  

> ⚠️ Only a single `ApplicationLoadBalancer` should be deployed.   

The deployed Application Load Balancer can be retrieved using the following command.

```powershell
kubectl get ApplicationLoadBalancer -n {{namespace}};
```

### Automatic Upgrades
Automatic upgrades ensure that the AKS cluster remains up to date with the latest security patches and node image updates. The `--auto-upgrade-channel patch` setting enables automatic 
Kubernetes patch version updates, helping keep the cluster secure with minimal manual intervention. In addition, `--node-os-upgrade-channel NodeImage` ensures that the underlying node 
operating system images are automatically updated, providing the latest fixes and improvements for the cluster nodes.  

### Node Scaling 
Cluster autoscaling in AKS automatically adjusts the number of nodes in a node pool based on workload demand. When enabled with `--enable-cluster-autoscaler`, AKS scales up when pods 
cannot be scheduled due to insufficient requested resources or scheduling constraints, and scales down when existing nodes are underutilized and workloads can be safely rescheduled. The 
`--min-count` and `--max-count` parameters define the scaling boundaries to ensure the cluster operates within a controlled range of nodes.  

When configuring the Horizontal Pod Autoscaler (HPA), Kubernetes uses resource requests as the baseline for scaling decisions. However, scaling is often intended to react closer to 
resource limits to better reflect actual capacity pressure. To achieve this, the target utilization can be derived using the formula below, which converts a desired scale percentage into 
the HPA average utilization value:

Formula: `Pod Resource Limit(L) x Desired Scale percentage(P) / Pod Resource Request(R) * 100 = HPA Average Utilization`  
Example: `2.100 * 80% / 700 * 100 = 240`  

> 💡 For more advanced and event-driven scaling scenarios, KEDA can be used to provide more fine-grained and configurable scaling options at the application level.  

### Network Policy
The AKS cluster is configured with the Azure CNI network plugin in overlay mode to enable scalable pod networking while conserving virtual network IP space. By using `--network-plugin azure` 
with `--network-plugin-mode=overlay`, pods receive IPs from an overlay network instead of the underlying VNet. The `--network-policy azure` setting enforces Azure Network Policies, 
allowing fine-grained control over traffic flow between pods and services to improve cluster security and isolation.  

### Private API Server
The AKS cluster is configured to use a private API server by integrating the control plane with the existing virtual network. By enabling private cluster mode and API server VNet integration, 
access to the Kubernetes control plane is restricted to the private network, eliminating any public endpoint exposure. The API server is hosted within the same virtual network infrastructure 
without requiring a separate dedicated subnet, ensuring that all communication with the control plane remains private and accessible only through connected network resources.  

This also means that interacting with the Kubernetes cluster using `kubectl` is restricted and requires a VPN connection to the Kubernetes virtual network. See [VPN Gateway](#vpn-gateway).

### DNS Resolver
The DNS Resolver setup provisions an Azure DNS Resolver within the virtual network and configures an inbound endpoint that is reachable from both VPN clients and resources running 
inside the VNet. This enables consistent resolution of private DNS zones, such as those used by Azure Private Endpoints for services like Azure Databases and Storage Accounts, without 
relying on manual DNS configuration or host-based overrides.

Once configured, the VPN gateway distributes the resolver’s IP address to connected clients as their DNS server. This ensures that any `privatelink` hostname is automatically resolved 
to its correct private IP address within the virtual network, allowing seamless connectivity to private Azure resources from local machines as well as from workloads running inside 
Kubernetes or other compute environments in the same network.  

> ⚠️ The DNS Resolver must be set before generating the VPN client profile, otherwise private DNS zones won’t be included and private endpoints won’t resolve from VPN-connected clients.

### VPN Gateway
The VPN Gateway provides secure remote access to the Kubernetes virtual network, enabling private connectivity to cluster resources such as the AKS API server and internal services. It is 
deployed using a route-based VPN gateway with a zone-redundant SKU to ensure high availability.  

A dedicated `GatewaySubnet` is created within the virtual network, and a public IP is assigned to the gateway for client connectivity. Azure automatically uses this subnet during gateway 
deployment. When selecting the `--address-prefix` for the subnet, ensure it does not overlap with existing subnet ranges and is fully contained within the VNet address space.  

To retrieve the address range of the VNet, run the following command.  

```powershell
az network vnet show -g $env:AZURE_RESOURCE_GROUP_ASSETS -n $env:VNET_NAME --query addressSpace.addressPrefixes -o tsv;
```

To identify the IP ranges already in use by existing subnets in the Kubernetes virtual network, use the following commands.  

```powershell
az network vnet subnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --vnet-name $env:VNET_NAME --query "[].{Name:name,Prefix:addressPrefix}" -o table
```

Point-to-site VPN configuration is enabled using Azure AD authentication, allowing users to securely connect using OpenVPN. A dedicated client address pool is allocated for 
VPN clients, ensuring isolated IP assignment within the network.

This setup ensures secure, identity-based access to the private Kubernetes environment without exposing internal resources publicly.

Download and install the Azure VPN Client for your operating system.  

| OS       | Link                                                                                 |
| -------- | ------------------------------------------------------------------------------------ |
| Linux    | https://apps.microsoft.com/detail/9np355qt2sqb                                       |
| Mac      | https://apps.apple.com/app/azure-vpn-client/id1557555267                             |
| Windows  | https://learn.microsoft.com/azure/vpn-gateway/point-to-site-vpn-client-cert-linux    |

Finally, run the following command to retrieve the VPN client configuration download link. Use this file to import the configuration into the Azure VPN Client.  

```powershell
az network vnet-gateway vpn-client generate `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n $env:VNET_GATEWAY_NAME;
```

> ⚠️ Creating the Gateway can take 20–30 minutes to complete.

### System Nodepool
The system nodepool is used to host critical Kubernetes system components such as DNS, metrics, and core add-ons. It is deployed in `System` mode and configured with dedicated compute 
resources to ensure stable and reliable cluster operations. To isolate system workloads from application workloads, the nodepool is tainted with `CriticalAddonsOnly=true:NoSchedule`, 
ensuring only system pods are scheduled on these nodes.  

Auto-scaling is enabled with a fixed range (min/max), allowing controlled scaling behavior while maintaining a minimum number of nodes for cluster stability. Host-level encryption is 
also enabled to improve security of data at rest on the nodes.  

After provisioning, the default nodepool is updated to run in `User` mode, ensuring a clear separation between system and application workloads.  

The system node pool is deployed across three availability zones to improve resiliency, fault tolerance, and workload availability within the cluster.  

### GPU Nodepool
The GPU nodepool is an optional dedicated nodepool designed to run workloads that require GPU acceleration, such as machine learning, AI inference, or compute-intensive processing tasks. It 
is configured in `User` mode and isolated from system workloads using a custom label (`nodepool.compute=gpu`) to allow targeted scheduling of GPU-enabled pods.  

Cluster autoscaling is enabled to dynamically adjust capacity based on demand, with a defined minimum and maximum node range to balance availability and cost. Host-level encryption is 
enabled to secure data at rest on GPU nodes, and GPU instance profiling is configured to support optimized GPU resource allocation.  

The GPU node pool is deployed across three availability zones to improve resiliency, fault tolerance, and workload availability within the cluster.  

### Maintenance Window
The maintenance window is configured to run on Sunday at 04:00 UTC, but can be adjusted to any time during the week based on operational requirements. This is done by modifying the 
`--weekday` and `--start-hour` parameters in the `deploy.ps1` script. The `--duration` parameter should be set to a minimum of 4 hours.

> ⚠️ Note that the Azure Portal does not display the default maintenance schedule unless custom update schedules are explicitly configured for the different maintenance controls.

### Monitoring
Monitoring is distributed across Container Insights, Azure Managed Prometheus, and Azure Managed Grafana, with each component responsible for a distinct layer of observability 
in the system.

Container Insights is used for centralized logging, Kubernetes events, and cluster inventory. It collects container stdout/stderr logs, Kubernetes events, and pod/node inventory from 
across the cluster, providing visibility into node and cluster availability and operational state through Log Analytics. Metrics collection through Container Insights is intentionally 
minimized because metrics are handled by Prometheus. The data collection rule is a production-oriented configuration and can be customized or omitted in development or test environments 
to reduce cost, with Azure defaults available as an alternative. The `--data-collection-settings` parameter controls this configuration during AKS enablement and can be adjusted later 
if requirements change.

Azure Managed Prometheus is used for collecting Kubernetes and application metrics, which form the basis for dashboards, analysis, and alerting. It is enabled through an Azure Monitor 
managed Prometheus workspace, which automatically provisions scraping and collection rules for Kubernetes metrics. Azure Managed Grafana is connected to the Prometheus workspace for 
visualization and deeper analysis of the collected metrics. Prometheus Rule Groups are used for metric-based alerting using PromQL expressions, with support for extending scraping 
configuration to include additional metrics beyond the default setup when required.

> ⚠️ Azure Prometheus uses different CRDs: `azmonitoring.coreos.com/v1` instead of `monitoring.coreos.com/v1`.  

The following table provides an overview of how observability responsibilities are distributed across the different Azure monitoring components in the AKS architecture.  

| Layer               | Azure Service                                   | Responsibility                                                    |
| ------------------- | ----------------------------------------------- | ----------------------------------------------------------------- |
| Application Metrics | Azure Managed Prometheus                        | Application, pod, node, and Kubernetes metrics.                   |
| Logging & Events    | Container Insights                              | Container logs, Kubernetes events, pod/node inventory.            |
| Dashboards          | Azure Managed Grafana                           | Metrics visualization and dashboards.                             |
| Alerting            | Prometheus Rule Groups                          | Metric-based alerting using PromQL.                               |

> 📖 Learn more about **[Azure Kubernetes Monitoring](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-tutorial)**.

### Alerts
Alerts are handled through Azure Managed Prometheus using Prometheus Rule Groups with PromQL-based expressions. Prometheus-based alerts provide higher accuracy and more detailed 
insights that the legacy Container Insight Alerts. The full set of Prometheus alerts is listed below.  

| Name                           | Description                                                   | Severity | Window Size |
| ------------------------------ | ------------------------------------------------------------- | -------- | ----------- |
| Node Not Ready                 | Node Ready condition is false                                 | Critical | PT5M        |
| Node Unreachable               | Node is marked with unreachable taint                         | Severe   | PT10M       |
| Node Readiness Flapping        | Frequent changes in Node Ready status                         | Warn     | PT10M       |
| Node Memory Pressure           | Node is under MemoryPressure condition                        | Severe   | PT5M        |
| Node CPU Pressure              | Node CPU usage is above 85%                                   | Severe   | PT5M        |
| Container CPU Rising           | Container CPU usage exceeds 60% of resource limits            | Warn     | PT10M       |
| Container CPU High             | Container CPU usage exceeds 80% of resource limits            | Severe   | PT10M       |
| Container CPU Critical         | Container CPU usage exceeds 95% of resource limits            | Critical | PT5M        |
| Container Memory Rising        | Container memory usage exceeds 60% of resource limits         | Warn     | PT10M       |
| Container Memory High          | Container memory usage exceeds 80% of resource limits         | Severe   | PT10M       |
| Container Memory Critical      | Container memory usage exceeds 95% of resource limits         | Critical | PT5M        |
| PV Usage High                  | PersistentVolume usage exceeds 80% capacity                   | Severe   | PT30M       |
| Hpa Maxed Out                  | HPA is at maximum replicas and cannot scale further           | Warn     | PT10M       |
| Hpa Replicas Mismatch          | Desired replicas differ from current replicas                 | Warn     | PT10M       |
| Daemon Set Not Scheduled       | Desired DaemonSet pods are not fully scheduled                | Warn     | PT10M       |
| Pod Scheduling Pressure        | Pods are stuck in Pending state                               | Warn     | PT10M       |
| Pod No tReady                  | Pods are in Pending, Unknown, or Failed state                 | Warn     | PT10M       |
| Pod Crash Looping              | Pods are in CrashLoopBackOff state                            | Info     | PT5M        |
| Pod Image Pull Failure         | Pods failing due to ImagePullBackOff or ErrImagePull          | Warn     | PT5M        |
| Container OOM Killed           | Containers terminated due to OOMKilled                        | Info     | PT5M        |
| PodRestart Rate High           | Pods with more than 3 restarts in 5 minutes                   | Warn     | PT5M        |
| Deployment Replicas Mismatch   | Available replicas do not match desired deployment replicas   | Info     | PT10M       |

For Container Insights, the following alerts are supplied in the `deploy.ps1` script. This is provided as a fallback in cases where Prometheus is not installed in the Kubernetes cluster.  

| Name                                     | Description                                         | Severity | Window Size |
| ---------------------------------------- | --------------------------------------------------- | -------- | ----------- |
| Node CPU Rising (60)                     | Node CPU sustained pressure above 60%               | Warn     | PT5M        |
| Node CPU High (80)                       | Node CPU usage above 80%                            | Severe   | PT5M        |
| Node CPU Critical (95)                   | Node CPU usage above 95%                            | Critical | PT5M        |
| Node Memory Rising (60)                  | Node memory sustained pressure above 60%            | Warn     | PT5M        |
| Node Memory High (80)                    | Node memory usage above 80%                         | Severe   | PT5M        |
| Node Memory Critical (95)                | Node memory usage above 95%                         | Critical | PT5M        |
| Node Disk High (80)                      | Node disk usage above 80%                           | Severe   | PT5M        |
| Container CPU High (Absolute NanoCores)  | Container CPU high usage (requires limits set)      | Severe   | PT5M        |
| Container Memory High (Absolute Bytes)   | Container memory high usage (absolute threshold)    | Severe   | PT5M        |
| Node Not Ready                           | Node is not in Ready state                          | Critical | PT5M        |
| Pod CrashLoopBackOff                     | Pods in CrashLoopBackOff state                      | Critical | PT5M        |
| Image Pull Failures                      | Image pull failures detected                        | Severe   | PT5M        |
| OOM Killed Containers                    | Containers terminated due to OOM                    | Critical | PT5M        |
| Pod Restart Rate High                    | High restart rate in last 5 minutes                 | Severe   | PT5M        |
| Pods Pending                             | Pods stuck in Pending state                         | Warn     | PT5M        |

> ⚠️ Legacy alerts are less precise and rely on fixed container thresholds (e.g. 800 mCPU) rather than percentage-based utilization of resource limits.

### Site Recovery
Backup and site recovery are not configured for the AKS cluster. The deployment follows an ephemeral infrastructure model, where workloads can be recreated at any time, and all critical 
data is stored in external managed services rather than within the cluster.

Enabling Kubernetes backup requires Private Endpoints between the AKS virtual network and the Backup Vault to ensure secure and private connectivity.  

### Image Cleaner
The Image Cleaner feature is optional and helps reduce disk usage on cluster nodes by automatically removing unused container images. When enabled, it periodically cleans up images that 
are no longer referenced by running workloads.

The cleanup interval is configured using `--image-cleaner-interval-hours`, which defines how frequently the process runs (e.g. every 72 hours). The value can be adjusted based on 
operational requirements.  

### Diagnostic Settings
Next, create the diagnostic settings for the Kubernetes (AKS) cluster.

AKS Diagnostic Settings are used for Kubernetes control plane and platform-level logs such as API server, audit, scheduler, autoscaler, and controller manager logs. Diagnostic metrics 
(`AllMetrics`) are intentionally disabled because Prometheus already handles metrics collection and alerting.

> ⚠️ If Prometheus is not installed, enable `Microsoft-InsightsMetrics` and `AllMetrics`.

You can retrieve the full list of supported metric and log categories for the Azure Kuberentes Cluster (AKS) resource using the following command.

```powershell
az monitor diagnostic-settings categories list --resource $env:KUBERNETES_ID;
```

Azure Load Balancer Diagnostic Settings are configured to collect `LoadBalancerHealthEvent` logs for backend probe failures and health status, with optional `AllMetrics` enabled using 
a 1-minute aggregation interval for metric collection.

You can retrieve the full list of supported metric and log categories for the Azure Load Balancer resource using the following command.

```powershell
az monitor diagnostic-settings categories list --resource $env:LOAD_BALANCER_ID;
```

Application Gateway for Containers (ALB) Diagnostic Settings are enabled to collect ingress access logs, providing visibility into HTTP requests, routing behavior, and response 
outcomes at the cluster edge.

You can retrieve the full list of supported metric and log categories for the Azure Application Load Balancer resource using the following command.

```powershell
az monitor diagnostic-settings categories list --resource $env:ALB_ID;
```

The following table provides an overview of log and metric coverage in Diagnostic Settings, outlining how observability responsibilities are distributed within the AKS architecture.

| Layer               | Azure Service                                   | Responsibility                                                    |
| ------------------- | ----------------------------------------------- | ----------------------------------------------------------------- |
| AKS Control Plane   | AKS Diagnostic Settings                         | API server, audit, scheduler, autoscaler, and controller logs.    |
| Azure Networking    | Azure Load Balancer Diagnostic Settings         | Load balancer health and probe events.                            |
| Edge / Ingress      | ALB Diagnostic Settings                         | Application Gateway for Containers access and firewall logs.      |

### Network Rules
The Kubernetes Cluster has no public access by default.

Optionally, IP address whitelisting can be configured to allow access to the storage file shares. By default, access is fully restricted, and no external connections are permitted. 
The Nano system does not depend on IP whitelisting for connectivity, and using it is generally discouraged as it can negatively impact the overall cloud security score. If IP 
whitelisting is required, it can be configured using the following command.  

```powershell
$env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS = "";

az aks updaate `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    -l $env:AZURE_LOCATION `
    --api-server-authorized-ip-ranges $env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS;
```

> ⚠️ Whitelisting IP addresses can reduce the overall security posture and negatively impact the security score.  

### Microsoft Defender
Microsoft Defender for Containers is used to enhance security monitoring and threat detection for the AKS cluster. It integrates with the Log Analytics workspace created via 
**[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)** to centralize security telemetry and enable 
vulnerability and runtime threat detection for container workloads.  

The Defender configuration is minimal and primarily used to link the cluster to the Log Analytics workspace through a generated configuration file. This file contains the workspace 
resource ID and is required during setup.

However, Microsoft Defender for AKS must still be explicitly enabled in the Azure Portal after deployment to fully activate security protections for the cluster.

### Azure Policy
Adds the default Azure Policy assignment to the cluster, enabling built-in compliance monitoring and governance enforcement. This provides visibility into configuration drift, 
security posture, and best-practice adherence, while continuously evaluating the cluster against Azure Policy definitions and initiatives.  

> 📖 Learn more about **[Azure Policy](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade.MenuView/~/Overview)**.

Installs the Gatekeeper/OPA addon on the AKS cluster itself, which is the enforcement engine that actually blocks the pods. Without it, the policy exists in Azure but nothing enforces 
it on the cluster.

To get the names of all policies, execute the following command.

```powershell
$env:SUBSCRIPTION_ID = "";
$env:POLICY_DEFINTION_ID = (az policy assignment show -n SecurityCenterBuiltIn --scope "/subscriptions/$env:SUBSCRIPTION_ID" --query policyDefinitionId -o tsv).Split('/')[-1];

az policy set-definition show -n $env:POLICY_DEFINTION_ID --query "parameters | keys(@)" -o tsv;
```

The following policies are configured on the cluster to enforce security boundaries at admission time.  

Container image pulls are restricted to a set of whitelisted registries (the cluster's own ACR, docker.io, quay.io, and ghcr.io). Any pod referencing an unlisted registry is denied before it 
runs, preventing malware from pulling images from unknown sources.  

Exposed service ports are limited to `8080`. Any workload attempting to open a different port is denied, preventing malware from binding to arbitrary ports.  

## Get kubectl Credentials
Once the cluster has been registered, retrieve the credentials using the following command.  

```powershell
az aks get-credentials -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --public-fqdn;
```

You can now use `kubectl` to manage the cluster.  

> ⚠️ Make sure you are connected the the VPn Gateway, if the Kubernetes cluster is set up with private access.  

## Common `kubectl` Commands
The following section contains commonly used Kubernetes (kubectl) commands for managing and troubleshooting resources in the cluster. These commands can be used to inspect workloads, view 
logs, monitor deployments, validate configuration, and diagnose issues related to networking, storage, and application health.  

List all Kubernetes nodes to view cluster infrastructure, status, and readiness of compute resources.  

```powershell
kubectl get nodes
```

Describe the `{{node-name}}` to inspect its capacity, conditions, system information, and scheduling details.  

```powershell
kubectl describe node {{node-name}};
```

Describe a pod with the `{{pod-name}}` in the `{{namespace}}` to inspect its full configuration, runtime status, and recent events for troubleshooting and validation.  

```powershell
kubectl describe pod {{pod-name}} -n {{namespace}};
```

List all pods in the `{{namespace}}` to view running workloads, status, and readiness information.  

```powershell
kubectl get pods -n {{namespace}};
```

View the highest resource-consuming pods in the `{{namespace}}` to monitor CPU and memory usage.  

```powershell
kubectl top pods -n {{namespace}}
```

Retrieve events for the `{{pod-name}}` in the `{{namespace}}` to analyze scheduling, warnings, and runtime issues.  

```powershell
kubectl events -n {{namespace}} --field-selector InvolvedObject.Name {{pod-name}};
```

Fetch logs from all pods labeled `{{app}}` and filter results using `{{search}}` to quickly locate relevant runtime output or errors.  

```powershell
kubectl logs -l -n {{namespace}} app={{app}} --tail -1 | findstr -i '{{search}}';
```

Manually trigger a new Kubernetes Job from an existing CronJob for immediate execution.  

```powershell
kubectl create job --from cronjob/{{cronjob-name}} {{job-name}}
```

Temporarily suspend a CronJob to prevent scheduled executions while maintaining its configuration in the cluster.  

```powershell
kubectl patch cronjob {{cronjob-name}} -p '{"spec": {"suspend": true}}'
```


```powershell
kubectl port-forward pod/<pod-name> 8080:80 -n {{namespace}}
```

## Dependencies
Kubernetes has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging.                      |
