$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "North Europe";
$env:AZURE_RESOURCE_GROUP = "Nano-Kubernetes";
$env:AZURE_RESOURCE_GROUP_ASSETS = "Nano-Kubernetes-Assets";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:AZURE_RESOURCE_GROUP_MYSQL = "Nano-Database";
$env:AZURE_RESOURCE_GROUP_STORAGE = "Nano-Storage";
$env:KUBERNETES_VERSION = "1.35.0";
$env:KUBERNETES_TIER = "standard";
$env:KUBERNETES_NODEPOOL_NAME = "default";
$env:KUBERNETES_NODEPOOL_LABEL_COMPUTE = "cpu"
$env:KUBERNETES_NODE_SIZE = "standard_d4as_v7"; 
$env:KUBERNETES_NODE_COUNT = 3;
$env:KUBERNETES_NODES_MIN = 3;
$env:KUBERNETES_NODES_MAX = 6;
$env:APP_NAME = $env:ENVIRONMENT.ToLower() + "-cluster";

# Register Providers
az provider register --namespace Microsoft.PolicyInsights;
az provider register --namespace Microsoft.ContainerService;

# Resource Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Create Cluster
az aks create `
    -g $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION `
    -n $env:APP_NAME `
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
    --network-plugin-mode=overlay `
    --network-policy azure `
    --generate-ssh-keys `
    --enable-encryption-at-host `
    --enable-managed-identity;

# Maintenance
az aks maintenanceconfiguration add `
    -g $env:AZURE_RESOURCE_GROUP `
    --name default `
    --cluster-name $env:APP_NAME `
    --weekday Sunday `
    --start-hour 4;

# Monitoring (Container insights)
$env:LOG_ANALYTICS_WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].[id] -o tsv;

az aks enable-addons `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    --addon monitoring `
    --workspace-resource-id $env:LOG_ANALYTICS_WORKSPACE_ID `
    --data-collection-settings '.data-collection-settings/data-collection-settings.json';

# Monitoring (Prometheus)
az extension add -n amg;
az config set extension.dynamic_install_allow_preview=true;

$env:MONITOR_WORKSPACE_ID = az monitor account list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].[id] -o tsv;

$env:GRAFANA_ID = az grafana create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME-grafana `
    -l $env:AZURE_LOCATION `
    --query id -o tsv;

az aks update `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    --enable-azure-monitor-metrics `
    --azure-monitor-workspace-resource-id $env:MONITOR_WORKSPACE_ID `
    --grafana-resource-id $env:GRAFANA_ID;

# Alerts.
# Navigate to the Monitor of the Kuberntes cluster in Azure portal, and set up the recommended Prometheus alerts.  

# Policy
az aks enable-addons `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --addons azure-policy;

# Defender
$env:DEFENDER_CONFIG = @{logAnalyticsWorkspaceResourceId = $env:LOG_ANALYTICS_WORKSPACE_ID} | ConvertTo-Json -Compress
$env:DEFENDER_CONFIG_FILE_PATH = Join-Path $env:USERPROFILE "nano.azure.kuberentes.defender-config.json"

Set-Content -Path $env:DEFENDER_CONFIG_FILE_PATH -Value $env:DEFENDER_CONFIG -Encoding utf8

az aks update `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    --enable-defender `
    --defender-config=$env:DEFENDER_CONFIG_FILE_PATH;

# Image Cleaner
az aks update `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    --enable-image-cleaner `
    --image-cleaner-interval-hours 72;

# Diagnostic Settings
$env:DIAGNOSTIC_SETTINGS_NAME = "diagnostics-" + $env:APP_NAME;
$env:KUBERNETES_ID = az aks list --query "[?name == '$env:APP_NAME'].[id]" -o tsv;

az monitor diagnostic-settings create `
    --name $env:DIAGNOSTIC_SETTINGS_NAME `
    --workspace $env:LOG_ANALYTICS_WORKSPACE_ID `
    --resource $env:KUBERNETES_ID `
    --logs '@.diagnostic-settings/logs.json' `
    --metrics '@.diagnostic-settings/metrics.json';

$env:DIAGNOSTIC_SETTINGS_LOAD_BALANCER_NAME = $env:DIAGNOSTIC_SETTINGS_NAME + "-load-balancer";
$env:LOAD_BALANCER_ID = az network lb list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query "[0].[id]" -o tsv;

az monitor diagnostic-settings create `
    --name $env:DIAGNOSTIC_SETTINGS_LOAD_BALANCER_NAME `
    --workspace $env:LOG_ANALYTICS_WORKSPACE_ID `
    --resource $env:LOAD_BALANCER_ID `
    --logs '@.diagnostic-settings/load-balancer-logs.json' `
    --metrics '@.diagnostic-settings/load-balancer-metrics.json';

# Network Rules.
$env:VNET_NAME = az network vnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query [0].name -o tsv;
$env:SUBNET_ID = az network vnet subnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --vnet-name $env:VNET_NAME --query [0].id -o tsv;
$env:SUBNET_NAME = az network vnet subnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --vnet-name $env:VNET_NAME --query [0].name -o tsv;

az network vnet subnet update `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    --vnet-name $env:VNET_NAME `
    --name $env:SUBNET_NAME `
    --service-endpoints Microsoft.Storage Microsoft.Sql;

$env:IP_ADDRESS = az network public-ip list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query [0].ipAddress -o tsv;
$env:RULE_NAME = $env:APP_NAME + "-rule";

$env:MYSQL_NAME = az mysql flexible-server list -g $env:AZURE_RESOURCE_GROUP_MYSQL --query "[0].[id]" -o tsv;

az mysql flexible-server firewall-rule create `
    -n $env:MYSQL_NAME `
    -g $env:AZURE_RESOURCE_GROUP_MYSQL `
    --rule-name kubernetes `
    --start-ip-address $env:IP_ADDRESS `
    --end-ip-address $env:IP_ADDRESS;

$env:STORAGE_ACCOUNT_NAME = az storage account list -g $env:AZURE_RESOURCE_GROUP_STORAGE --query "[0].[name]" -o tsv;

az storage account network-rule add `
    -g $env:AZURE_RESOURCE_GROUP_STORAGE `
    --account-name $env:STORAGE_ACCOUNT_NAME `
    --subnet $env:SUBNET_ID;

# System Nodepool (Optional)
$env:KUBERNETES_NODEPOOL_SYSTEM_NAME = "system";
$env:KUBERNETES_SYSTEM_NODE_SIZE = "standard_d4as_v7"; 
$env:KUBERNETES_SYSTEM_NODE_COUNT=1
$env:KUBERNETES_SYSTEM_NODES_MIN=1
$env:KUBERNETES_SYSTEM_NODES_MAX=2

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
    --enable-cluster-autoscaler;

az aks nodepool update `
    -g $env:AZURE_RESOURCE_GROUP `
    --cluster-name $env:APP_NAME `
    --name $env:KUBERNETES_NODEPOOL_NAME `
    --mode user;

# GPU Nodepool (Optional)
$env:KUBERNETES_NODEPOOL_GPU_NAME = "gpu";
$env:KUBERNETES_GPU_NODE_SIZE = ""; 
$env:KUBERNETES_GPU_NODE_COUNT=1
$env:KUBERNETES_GPU_NODES_MIN=1
$env:KUBERNETES_GPU_NODES_MAX=1

az aks nodepool add `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:KUBERNETES_NODEPOOL_GPU_NAME `
    --cluster-name $env:KUBERNETES_CLUSTER `
    --kubernetes-version $env:KUBERNETES_VERSION `
    --mode User `
    --os-type Linux `
    --node-vm-size $env:KUBERNETES_NODE_SIZE `
    --node-count $env:KUBERNETES_GPU_NODE_COUNT `
    --min-count $env:KUBERNETES_GPU_NODES_MIN `
    --max-count $env:KUBERNETES_GPU_NODES_MAX `
    --labels nodepool.compute=gpu `
    --enable-cluster-autoscaler `
    --enable-encryption-at-host `
    --gpu-instance-profile MIG1g;
