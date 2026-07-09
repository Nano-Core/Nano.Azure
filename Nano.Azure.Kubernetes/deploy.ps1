$env:ENVIRONMENT = "";
$env:AZURE_TENANT_ID = "";
$env:AZURE_LOCATION = "North Europe";
$env:AZURE_RESOURCE_GROUP = "Nano-Kubernetes";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:AZURE_RESOURCE_GROUP_ASSETS = "Nano-Kubernetes-Assets";
$env:AZURE_RESOURCE_GROUP_DELIVERY = "Nano-Delivery";
$env:KUBERNETES_VERSION = "1.36.0";
$env:KUBERNETES_TIER = "standard";
$env:KUBERNETES_NODEPOOL_NAME = "default";
$env:KUBERNETES_NODEPOOL_LABEL_COMPUTE = "cpu"
$env:KUBERNETES_NODE_SIZE = "standard_d2as_v6"; 
$env:KUBERNETES_NODE_COUNT = 3;
$env:KUBERNETES_NODES_MIN = 3;
$env:KUBERNETES_NODES_MAX = 6;
$env:APP_NAME = $env:ENVIRONMENT.ToLower() + "-cluster";

# Register Providers
az provider register --namespace Microsoft.PolicyInsights;
az provider register --namespace Microsoft.Network;
az provider register --namespace Microsoft.NetworkFunction;
az provider register --namespace Microsoft.ServiceNetworking;

az feature register --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview";
az feature register --namespace "Microsoft.ContainerService" --name "ApplicationLoadBalancerPreview";

az extension add --name alb;
az extension add --name aks-preview;

# Resource Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Kubernetes Cluster
az aks create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    -l $env:AZURE_LOCATION `
    --tier $env:KUBERNETES_TIER `
    --kubernetes-version $env:KUBERNETES_VERSION `
    --node-count $env:KUBERNETES_NODE_COUNT `
    --node-resource-group $env:AZURE_RESOURCE_GROUP_ASSETS `
    --node-vm-size $env:KUBERNETES_NODE_SIZE `
    --nodepool-name $env:KUBERNETES_NODEPOOL_NAME `
    --nodepool-labels nodepool.compute=$env:KUBERNETES_NODEPOOL_LABEL_COMPUTE `
    --node-os-upgrade-channel NodeImage `
    --auto-upgrade-channel patch `
    --enable-cluster-autoscaler `
    --max-count $env:KUBERNETES_NODES_MAX `
    --min-count $env:KUBERNETES_NODES_MIN `
    --network-plugin azure `
    --network-plugin-mode overlay `
    --network-policy azure `
    --enable-encryption-at-host `
    --enable-private-cluster `
    --enable-managed-identity `
    --enable-workload-identity `
    --enable-oidc-issuer `
    --enable-gateway-api `
    --enable-application-load-balancer `
    --ssh-access Disabled `
    --zones 1 2 3;

# Load Balancer
$env:SUBNET_ALB_NAME = "aks-subnet-alb"; 
$env:SUBNET_ADDRESS_PREFIXES = "10.230.0.0/24";
$env:VNET_NAME = az network vnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query [0].name -o tsv;

az network vnet subnet create `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n $env:SUBNET_ALB_NAME `
    --vnet-name $env:VNET_NAME `
    --address-prefixes $env:SUBNET_ADDRESS_PREFIXES `
    --delegations 'Microsoft.ServiceNetworking/trafficControllers';

$env:ALB_IDENTITY_NAME = az identity list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query "[?contains(name, 'applicationloadbalancer')].name" -o tsv
$env:PRINCIPAL_ID = az identity show -g $env:AZURE_RESOURCE_GROUP_ASSETS -n $env:ALB_IDENTITY_NAME --query principalId -o tsv;
$env:ALB_SUBNET_ID = az network vnet subnet show -n $env:SUBNET_ALB_NAME -g $env:AZURE_RESOURCE_GROUP_ASSETS --vnet-name $env:VNET_NAME --query id -o tsv;
$env:AZURE_RESOURCE_GROUP_ASSETS_ID = az group show -n $env:AZURE_RESOURCE_GROUP_ASSETS --query id;

az role assignment create `
    --assignee-object-id $env:PRINCIPAL_ID `
    --assignee-principal-type ServicePrincipal `
    --scope $env:AZURE_RESOURCE_GROUP_ASSETS_ID `
    --role "Contributor";

az role assignment create `
    --assignee-object-id $env:PRINCIPAL_ID `
    --assignee-principal-type ServicePrincipal `
    --scope $env:ALB_SUBNET_ID `
    --role "Network Contributor";

$env:KUBERNETES_NAMESPACE = "apps";
$env:VNET_NAME = az network vnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query [0].name -o tsv;
$env:ALB_SUBNET_ID = az network vnet subnet show -n $env:SUBNET_ALB_NAME -g $env:AZURE_RESOURCE_GROUP_ASSETS --vnet-name $env:VNET_NAME --query id -o tsv;
$env:APPLICATION_LOAD_BALANCER_PATH = Join-Path $env:USERPROFILE "application-load-balancer.yaml";

Get-Content .kubernetes/application-load-balancer.yaml | foreach { [Environment]::ExpandEnvironmentVariables($_) } | Set-Content $env:APPLICATION_LOAD_BALANCER_PATH;

az aks command invoke `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    --file $env:APPLICATION_LOAD_BALANCER_PATH `
    --command "kubectl apply -f application-load-balancer.yaml" `
    --output json | ConvertFrom-Json;

# DNS Resolver
$env:DNS_RESOLVER_NAME = $env:APP_NAME + "-dns-resolver";
$env:SUBNET_DNS_RESOLVER_NAME = "aks-dns-resolver-subnet";
$env:VNET_ID = az network vnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query [0].id -o tsv;

az extension add --name dns-resolver;

az dns-resolver create `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n $env:DNS_RESOLVER_NAME `
    -l $env:AZURE_LOCATION `
    --id $env:VNET_ID;

$env:VNET_NAME = az network vnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query [0].name -o tsv;
$env:SUBNET_ADDRESS_PREFIXES = "10.233.0.0/28";

az network vnet subnet create `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n $env:SUBNET_DNS_RESOLVER_NAME `
    --vnet-name $env:VNET_NAME `
    --address-prefixes $env:SUBNET_ADDRESS_PREFIXES `
    --delegations "Microsoft.Network/dnsResolvers";

$env:DNS_RESOLVER_SUBNET_ID = az network vnet subnet show -g $env:AZURE_RESOURCE_GROUP_ASSETS -n $env:SUBNET_DNS_RESOLVER_NAME --vnet-name $env:VNET_NAME --query id -o tsv;

az dns-resolver inbound-endpoint create `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -l $env:AZURE_LOCATION `
    --name inbound `
    --dns-resolver-name $env:DNS_RESOLVER_NAME `
    --ip-configurations "[{private-ip-address:'',private-ip-allocation-method:'Dynamic',id:'$($env:DNS_RESOLVER_SUBNET_ID)'}]";

$env:DNS_RESOLVER_PRIVATE_ID = az dns-resolver inbound-endpoint show -g $env:AZURE_RESOURCE_GROUP_ASSETS --dns-resolver-name $env:DNS_RESOLVER_NAME --name inbound --query ipConfigurations[0].privateIpAddress -o tsv;

az network vnet update `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n $env:VNET_NAME `
    --dns-servers $env:DNS_RESOLVER_PRIVATE_ID;

# VPN Gateway
$env:VNET_ID = az network vnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query [0].id -o tsv;
$env:VNET_NAME = az network vnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query [0].name -o tsv;
$env:VNET_GATEWAY_NAME = $env:APP_NAME + "-vnet-vpn-gateway";
$env:VNET_GATEWAY_IP_NAME = $env:APP_NAME + "-vnet-vpn-gateway-ip";
$env:VNET_GATEWAY_VPN_CLIENT_ADDRESS_POOL = "['172.16.201.0/24']";
$env:VNET_GATEWAY_ADD_TENANT = "https://login.microsoftonline.com/" + $env:AZURE_TENANT_ID;
$env:VNET_GATEWAY_ADD_AUDIENCE = "c632b3df-fb67-4d84-bdcf-b95ad541b5c8";
$env:VNET_GATEWAY_ADD_ISSUER = "https://sts.windows.net/" + $env:AZURE_TENANT_ID + "/";
$env:SUBNET_ADDRESS_PREFIXES = "10.231.0.0/24";

az network public-ip create `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n $env:VNET_GATEWAY_IP_NAME `
    -z 1 2 3 `
    --sku Standard `
    --allocation-method Static;

az network vnet subnet create `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n GatewaySubnet `
    --vnet-name $env:VNET_NAME `
    --address-prefix $env:SUBNET_ADDRESS_PREFIXES;

az network vnet-gateway create `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n $env:VNET_GATEWAY_NAME `
    --public-ip-address $env:VNET_GATEWAY_IP_NAME `
    --vnet $env:VNET_ID `
    --gateway-type Vpn `
    --vpn-type RouteBased `
    --sku VpnGw1AZ `
    --vpn-gateway-generation Generation2;

az network vnet-gateway update `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n $env:VNET_GATEWAY_NAME `
    --set "vpnClientConfiguration.vpnClientAddressPool.addressPrefixes=$env:VNET_GATEWAY_VPN_CLIENT_ADDRESS_POOL" `
    --set "vpnClientConfiguration.vpnClientProtocols=['OpenVPN']" `
    --set "vpnClientConfiguration.vpnAuthenticationTypes=['Aad']" `
    --set vpnClientConfiguration.aadTenant=$env:VNET_GATEWAY_ADD_TENANT `
    --set vpnClientConfiguration.aadAudience=$env:VNET_GATEWAY_ADD_AUDIENCE `
    --set vpnClientConfiguration.aadIssuer=$env:VNET_GATEWAY_ADD_ISSUER;

az network vnet-gateway vpn-client generate `
  -g $env:AZURE_RESOURCE_GROUP_ASSETS `
  -n $env:VNET_GATEWAY_NAME;

# System Nodepool
$env:KUBERNETES_NODEPOOL_SYSTEM_NAME = "system";
$env:KUBERNETES_SYSTEM_NODE_SIZE = "standard_d2as_v6"; 
$env:KUBERNETES_SYSTEM_NODE_COUNT=3;
$env:KUBERNETES_SYSTEM_NODES_MIN=3;
$env:KUBERNETES_SYSTEM_NODES_MAX=3;

az aks nodepool add `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:KUBERNETES_NODEPOOL_SYSTEM_NAME `
    --cluster-name $env:APP_NAME `
    --kubernetes-version $env:KUBERNETES_VERSION `
    --mode System `
    --os-type Linux `
    --node-taints CriticalAddonsOnly=true:NoSchedule `
    --node-vm-size $env:KUBERNETES_SYSTEM_NODE_SIZE `
    --node-count $env:KUBERNETES_SYSTEM_NODE_COUNT `
    --min-count $env:KUBERNETES_SYSTEM_NODES_MIN `
    --max-count $env:KUBERNETES_SYSTEM_NODES_MAX `
    --enable-encryption-at-host `
    --enable-cluster-autoscaler `
    --ssh-access Disabled `
    --zones 1 2 3;

az aks nodepool update `
    -g $env:AZURE_RESOURCE_GROUP `
    --cluster-name $env:APP_NAME `
    --name $env:KUBERNETES_NODEPOOL_NAME `
    --mode user;

# GPU Nodepool (Optional)
$env:KUBERNETES_NODEPOOL_GPU_NAME = "gpu";
$env:KUBERNETES_GPU_NODE_SIZE = ""; 
$env:KUBERNETES_GPU_NODE_COUNT=1;
$env:KUBERNETES_GPU_NODES_MIN=1;
$env:KUBERNETES_GPU_NODES_MAX=3;

az aks nodepool add `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:KUBERNETES_NODEPOOL_GPU_NAME `
    --cluster-name $env:APP_NAME `
    --kubernetes-version $env:KUBERNETES_VERSION `
    --mode User `
    --os-type Linux `
    --node-vm-size $env:KUBERNETES_GPU_NODE_SIZE `
    --node-count $env:KUBERNETES_GPU_NODE_COUNT `
    --min-count $env:KUBERNETES_GPU_NODES_MIN `
    --max-count $env:KUBERNETES_GPU_NODES_MAX `
    --labels nodepool.compute=gpu `
    --enable-cluster-autoscaler `
    --enable-encryption-at-host `
    --gpu-driver Install `
    --gpu-instance-profile MIG1g `
    --ssh-access Disabled `
    --zones 1 2 3;

# Maintenance
az aks maintenanceconfiguration add `
  -g $env:AZURE_RESOURCE_GROUP `
  --cluster-name $env:APP_NAME `
  --name aksManagedNodeOSUpgradeSchedule `
  --weekday Monday
  --start-hour 4 `
  --duration 4

az aks maintenanceconfiguration add `
  -g $env:AZURE_RESOURCE_GROUP `
  --cluster-name $env:APP_NAME `
  --name aksManagedAutoUpgradeSchedule `
  --schedule-type Weekly `
  --day-of-week Sunday `
  --interval-weeks 1 `
  --start-time 00:00 `
  --duration 4 `
  --utc-offset +00:00

# Monitoring (Container Insights)
$env:LOG_ANALYTICS_WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].id -o tsv;

az aks enable-addons `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    --addon monitoring `
    --workspace-resource-id $env:LOG_ANALYTICS_WORKSPACE_ID `
    --data-collection-settings '.data-collection-settings/data-collection-settings.json';

# Monitoring (Prometheus)
az extension add -n amg;
az config set extension.dynamic_install_allow_preview=true;

$env:APP_NAME_GRAFANA = "grafana-" + (Get-Random -Maximum 999999).ToString("D6");
$env:MONITOR_WORKSPACE_ID = az monitor account list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].id -o tsv;

$env:GRAFANA_ID = az grafana create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME_GRAFANA `
    -l $env:AZURE_LOCATION `
    --query id -o tsv;

az aks update `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    --enable-azure-monitor-metrics `
    --azure-monitor-workspace-resource-id $env:MONITOR_WORKSPACE_ID `
    --grafana-resource-id $env:GRAFANA_ID;

# Alerts (Prometheus)
az extension add -n alertsmanagement;

$env:ACTION_GROUP = az monitor action-group list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].id -o tsv;

az alerts-management prometheus-rule-group create `
  --name 'Prometheus Alerts - Resource Saturation' `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --location $env:AZURE_LOCATION `
  --cluster-name $env:APP_NAME `
  --enabled true `
  --description "Resource saturation alerts" `
  --interval PT5M `
  --scopes $env:MONITOR_WORKSPACE_ID `
  --rules '.alerts/resource-saturation.json';

az alerts-management prometheus-rule-group create `
  --name 'Prometheus Alerts - Workload Stability' `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --location $env:AZURE_LOCATION `
  --cluster-name $env:APP_NAME `
  --enabled true `
  --description "Workload stability alerts" `
  --interval PT5M `
  --scopes $env:MONITOR_WORKSPACE_ID `
  --rules '.alerts/workload-stability.json';

az alerts-management prometheus-rule-group create `
  --name 'Prometheus Alerts - Scheduling Scaling' `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --location $env:AZURE_LOCATION `
  --cluster-name $env:APP_NAME `
  --enabled true `
  --description "Scheduling scaling alerts" `
  --interval PT5M `
  --scopes $env:MONITOR_WORKSPACE_ID `
  --rules '.alerts/scheduling-scaling.json';

az alerts-management prometheus-rule-group create `
  --name 'Prometheus Alerts - Node Health' `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --location $env:AZURE_LOCATION `
  --cluster-name $env:APP_NAME `
  --enabled true `
  --description "Node health alerts" `
  --interval PT5M `
  --scopes $env:MONITOR_WORKSPACE_ID `
  --rules '.alerts/node-health.json';

# Alerts (Legacy)
az extension add --name scheduled-query;

$env:KUBERNETES_ID = az aks show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
$env:ACTION_GROUP = az monitor action-group list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].id -o tsv;

az monitor metrics alert create `
  --name "Node CPU Rising (60)" `
  --description "Node CPU sustained pressure above 60%." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:KUBERNETES_ID `
  --condition "avg node_cpu_usage_percentage > 60" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 3;

az monitor metrics alert create `
  --name "Node CPU High (80)" `
  --description "Node CPU usage above 80%." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:KUBERNETES_ID `
  --condition "avg node_cpu_usage_percentage > 80" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 2;

az monitor metrics alert create `
  --name "Node CPU Critical (95)" `
  --description "Node CPU usage above 95%." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:KUBERNETES_ID `
  --condition "avg node_cpu_usage_percentage > 95" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 1;

az monitor metrics alert create `
  --name "Node Memory Rising (60)" `
  --description "Node memory sustained pressure above 60%." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:KUBERNETES_ID `
  --condition "avg node_memory_working_set_percentage > 60" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 3;

az monitor metrics alert create `
  --name "Node Memory High (80)" `
  --description "Node memory usage above 80%." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:KUBERNETES_ID `
  --condition "avg node_memory_working_set_percentage > 80" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 2;

az monitor metrics alert create `
  --name "Node Memory Critical (95)" `
  --description "Node memory usage above 95%." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:KUBERNETES_ID `
  --condition "avg node_memory_working_set_percentage > 95" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 1;

az monitor metrics alert create `
  --name "Node Disk High (80)" `
  --description "Node disk usage above 80%." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:KUBERNETES_ID `
  --condition "avg node_disk_usage_percentage > 80" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 2;

az monitor scheduled-query create `
  --name "Container CPU High (Absolute NanoCores)" `
  --description "Container CPU high usage (requires limits set)." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:LOG_ANALYTICS_WORKSPACE_ID `
  --condition "count 'InsightsMetrics | where TimeGenerated > ago(5m) | where Name == \'cpuUsageNanoCores\' | where Val > 800000000' > 0" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --location $env:AZURE_LOCATION `
  --severity 2;

az monitor scheduled-query create `
  --name "Container Memory High (Absolute Bytes)" `
  --description "Container memory high usage (absolute threshold)." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:LOG_ANALYTICS_WORKSPACE_ID `
  --condition "count 'InsightsMetrics | where TimeGenerated > ago(5m) | where Name == \'memoryWorkingSetBytes\' | where Val > 800000000' > 0" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --location $env:AZURE_LOCATION `
  --severity 2;

az monitor scheduled-query create `
  --name "Node Not Ready" `
  --description "Node is not in Ready state." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:LOG_ANALYTICS_WORKSPACE_ID `
  --condition "count 'KubePodInventory | where PodStatus != \'Running\' | summarize count() by Name' > 0" `
  --evaluation-frequency PT1M `
  --window-size PT5M `
  --action $env:ACTION_GROUP `
  --location $env:AZURE_LOCATION `
  --severity 1;

az monitor scheduled-query create `
  --name "Pod CrashLoopBackOff" `
  --description "Pods in CrashLoopBackOff state." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:LOG_ANALYTICS_WORKSPACE_ID `
  --condition "count 'KubePodInventory | where ContainerStatusReason == \'CrashLoopBackOff\'' > 0" `
  --evaluation-frequency PT5M `
  --window-size PT5M `
  --action $env:ACTION_GROUP `
  --location $env:AZURE_LOCATION `
  --severity 1;

az monitor scheduled-query create `
  --name "Image Pull Failures" `
  --description "Image pull failures detected." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:LOG_ANALYTICS_WORKSPACE_ID `
  --condition "count 'KubePodInventory | where ContainerStatusReason in (\'ImagePullBackOff\',\'ErrImagePull\')' > 0" `
  --evaluation-frequency PT5M `
  --window-size PT5M `
  --action $env:ACTION_GROUP `
  --location $env:AZURE_LOCATION `
  --severity 2;

az monitor scheduled-query create `
  --name "OOM Killed Containers" `
  --description "Containers terminated due to OOM." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:LOG_ANALYTICS_WORKSPACE_ID `
  --condition "count 'KubePodInventory | where ContainerStatusReason == \'OOMKilled\'' > 0" `
  --evaluation-frequency PT5M `
  --window-size PT5M `
  --action $env:ACTION_GROUP `
  --location $env:AZURE_LOCATION `
  --severity 1;

az monitor scheduled-query create `
  --name "Pod Restart Rate High" `
  --description "High restart rate in last 5 minutes." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:LOG_ANALYTICS_WORKSPACE_ID `
  --condition "count 'KubePodInventory | where TimeGenerated > ago(5m) | where ContainerRestartCount > 3' > 0" `
  --evaluation-frequency PT1M `
  --window-size PT5M `
  --action $env:ACTION_GROUP `
  --location $env:AZURE_LOCATION `
  --severity 2;
    
az monitor scheduled-query create `
  --name "Pods Pending" `
  --description "Pods stuck in Pending state." `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:LOG_ANALYTICS_WORKSPACE_ID `
  --condition "count 'KubePodInventory | where PodStatus == \'Pending\' | summarize count()' > 0" `
  --evaluation-frequency PT1M `
  --window-size PT5M `
  --action $env:ACTION_GROUP `
  --location $env:AZURE_LOCATION `
  --severity 3;
  
# Image Cleaner (Optional)
az aks update `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    --enable-image-cleaner `
    --image-cleaner-interval-hours 72;

# Diagnostic Settings
$env:LOG_ANALYTICS_WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].id -o tsv;
$env:KUBERNETES_ID = az aks show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
$env:DIAGNOSTIC_SETTINGS_NAME = "diagnostics-" + $env:APP_NAME;

az monitor diagnostic-settings create `
    --name $env:DIAGNOSTIC_SETTINGS_NAME `
    --workspace $env:LOG_ANALYTICS_WORKSPACE_ID `
    --resource $env:KUBERNETES_ID `
    --logs '@.diagnostic-settings/logs.json';

$env:LOAD_BALANCER_ID = az network lb show -g $env:AZURE_RESOURCE_GROUP_ASSETS -n kubernetes --query id -o tsv;
$env:DIAGNOSTIC_SETTINGS_LOAD_BALANCER_NAME = $env:DIAGNOSTIC_SETTINGS_NAME + "-load-balancer";

az monitor diagnostic-settings create `
    --name $env:DIAGNOSTIC_SETTINGS_LOAD_BALANCER_NAME `
    --workspace $env:LOG_ANALYTICS_WORKSPACE_ID `
    --resource $env:LOAD_BALANCER_ID `
    --logs '@.diagnostic-settings/load-balancer/logs.json' `
    --metrics '@.diagnostic-settings/load-balancer/metrics.json';

$env:ALB_LOAD_BALANCER_ID = az network alb list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query [0].id -o tsv;
$env:DIAGNOSTIC_SETTINGS_ALB_LOAD_BALANCER_NAME = $env:DIAGNOSTIC_SETTINGS_NAME + "-alb";

az monitor diagnostic-settings create `
    --name $env:DIAGNOSTIC_SETTINGS_ALB_LOAD_BALANCER_NAME `
    --workspace $env:LOG_ANALYTICS_WORKSPACE_ID `
    --resource $env:ALB_LOAD_BALANCER_ID `
    --logs '@.diagnostic-settings/alb/logs.json';

# Microsoft Defender
$env:DEFENDER_CONFIG = @{logAnalyticsWorkspaceResourceId = $env:LOG_ANALYTICS_WORKSPACE_ID} | ConvertTo-Json -Compress
$env:DEFENDER_CONFIG_FILE_PATH = Join-Path $env:USERPROFILE "nano.azure.kuberentes.defender-config.json"

Set-Content -Path $env:DEFENDER_CONFIG_FILE_PATH -Value $env:DEFENDER_CONFIG -Encoding utf8

az aks update `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    --enable-defender `
    --defender-config=$env:DEFENDER_CONFIG_FILE_PATH;

# Policies
az aks enable-addons `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --addons azure-policy;

$env:AZURE_SUBSCRIPTION_ID = "";
$env:ACR_HOST = (az acr list -g $env:AZURE_RESOURCE_GROUP_DELIVERY --query "[0].loginServer" -o tsv)

$params = @{
    allowedContainerImagesInKubernetesClusterRegex = @{ value = "^($env:ACR_HOST|docker.io|registry-1.docker.io|index.docker.io|mcr.microsoft.com|quay.io|ghcr.io)/.+" }
    allowedContainerImagesInKubernetesClusterEffect = @{ value = "deny" }
    allowedservicePortsInKubernetesClusterPorts = @{ value = @("8080") }
    allowedservicePortsInKubernetesClusterEffect = @{ value = "deny" }
} | ConvertTo-Json -Compress 

az policy assignment update `
    -n SecurityCenterBuiltIn `
    --scope "/subscriptions/$env:AZURE_SUBSCRIPTION_ID" `
    --params $params;
