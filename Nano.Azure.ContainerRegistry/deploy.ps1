$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "North Europe";
$env:AZURE_RESOURCE_GROUP = "Nano-Delivery";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:AZURE_RESOURCE_GROUP_KUBERNETES = "Nano-Kubernetes";
$env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS = "Nano-Kubernetes-Assets";
$env:APP_NAME = "nano" + $env:ENVIRONMENT.ToLower() + "containerregistry";

# Register Providers
az provider register --namespace Microsoft.ContainerRegistry;

# Create Azure Container Registry (ACR)
$env:LOG_ANALYTICS_WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].id -o tsv;

az acr create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    -l $env:AZURE_LOCATION `
    --sku Premium `
    --workspace $env:LOG_ANALYTICS_WORKSPACE_ID `
    --public-network-enabled true `
    --allow-trusted-services true `
    --default-action Deny `
    --admin-enabled false `
    --zone-redundancy Enabled;

# Agent Pool (Optional)
$env:SUBNET_ACR_NAME = "aks-subnet-acr"; 
$env:SUBNET_ADDRESS_PREFIXES = "10.234.0.0/24";
$env:VNET_NAME = az network vnet list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS --query [0].name -o tsv;

az network vnet subnet create `
    -g $env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS `
    -n $env:SUBNET_ACR_NAME `
    --vnet-name $env:VNET_NAME `
    --address-prefixes $env:SUBNET_ADDRESS_PREFIXES `
    --service-endpoints `
        Microsoft.AzureActiveDirectory `
        Microsoft.EventHub `
        Microsoft.KeyVault `
        Microsoft.Storage;

$env:SUBNET_ACR_ID = az network vnet subnet show -n $env:SUBNET_ACR_NAME -g $env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS --vnet-name $env:VNET_NAME --query id -o tsv;

az acr agentpool create `
    -n buildpool `
    -r $env:APP_NAME `
    --tier S2 `
    --count 1 `
    --subnet-id $env:SUBNET_ACR_ID;

# Attach ACR to AKS
$env:CONTAINER_REGISTRY_ID = az acr show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
$env:KUBERNETES_NAME = az aks list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES --query [0].name -o tsv;

az aks update `
    -n $env:KUBERNETES_NAME `
    -g $env:AZURE_RESOURCE_GROUP_KUBERNETES `
    --attach-acr $env:CONTAINER_REGISTRY_ID;

# Network Rules.
$env:PRIVATE_LINK = "privatelink.azurecr.io";
$env:PRIVATE_ENDPOINT_NAME = $env:APP_NAME + "-private-endpoint";
$env:ACR_ID = az acr show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
$env:VNET_ID = az network vnet list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS --query [0].id -o tsv;
$env:VNET_NAME = az network vnet list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS --query [0].name -o tsv;
$env:VNET_LOCATION = az network vnet list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS --query [0].location -o tsv;
$env:SUBNET_ID = az network vnet subnet list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS --vnet-name $env:VNET_NAME --query "[?name =='aks-subnet'].[id]" -o tsv;

az network private-dns zone create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:PRIVATE_LINK;

az network private-dns link vnet create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:PRIVATE_ENDPOINT_NAME-dns-link `
    -z $env:PRIVATE_LINK `
    -v $env:VNET_ID `
    -e false;

az network private-endpoint create `
    -l $env:VNET_LOCATION `
    --name $env:PRIVATE_ENDPOINT_NAME `
    --connection-name $env:PRIVATE_ENDPOINT_NAME-connection `
    --nic-name $env:PRIVATE_ENDPOINT_NAME-nic `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --group-id registry `
    --subnet $env:SUBNET_ID `
    --private-connection-resource-id $env:ACR_ID;

az network private-endpoint dns-zone-group create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:PRIVATE_ENDPOINT_NAME-dns-zone-group `
    --endpoint-name $env:PRIVATE_ENDPOINT_NAME `
    --private-dns-zone $env:PRIVATE_LINK `
    --zone-name registry;
