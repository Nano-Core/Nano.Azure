$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "North Europe";
$env:AZURE_RESOURCE_GROUP = "Nano-Delivery";
$env:AZURE_RESOURCE_GROUP_ASSETS = "Nano-Delivery-Assets";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:AZURE_RESOURCE_GROUP_ASSETS = "Nano-Kubernetes-Assets";
$env:APP_NAME = $env:ENVIRONMENT + "-delivery-platform";

# Register Providers
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.OperationalInsights

# Resurce Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Container App Environment
$env:SUBNET_NAME = "aks-subnet-ci"; 
$env:SUBNET_ADDRESS_PREFIXES = "10.232.0.0/24";
$env:VNET_NAME = az network vnet list -g $env:AZURE_RESOURCE_GROUP_ASSETS --query [0].name -o tsv;

az network vnet subnet create `
    -g $env:AZURE_RESOURCE_GROUP_ASSETS `
    -n $env:SUBNET_NAME `
    --vnet-name $env:VNET_NAME `
    --address-prefixes $env:SUBNET_ADDRESS_PREFIXES `
    --delegations "Microsoft.App/environments";

$env:SUBNET_ID = az network vnet subnet show -g $env:AZURE_RESOURCE_GROUP_ASSETS -n $env:SUBNET_NAME --vnet-name $env:VNET_NAME --query id --output tsv;
$env:LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].customerId -o tsv;
$env:LOG_ANALYTICS_WORKSPACE_NAME = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].name -o tsv;
$env:LOG_ANALYTICS_WORKSPACE_KEY = az monitor log-analytics workspace get-shareD-keys -g $env:AZURE_RESOURCE_GROUP_LOGS -n $env:LOG_ANALYTICS_WORKSPACE_NAME --query primarySharedKey -o tsv

az containerapp env create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    -l $env:AZURE_LOCATION `
    --infrastructure-resource-group $env:AZURE_RESOURCE_GROUP_ASSETS `
    --infrastructure-subnet-resource-id $env:SUBNET_ID `
    --logs-destination log-analytics `
    --logs-workspace-id $env:LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID `
    --logs-workspace-key $env:LOG_ANALYTICS_WORKSPACE_KEY `
    --internal-only true `
    --zone-redundant;
