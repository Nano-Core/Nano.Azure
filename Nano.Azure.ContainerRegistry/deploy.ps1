$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "North Europe";
$env:AZURE_RESOURCE_GROUP_DELIVERY = "Nano-Delivery";
$env:AZURE_RESOURCE_GROUP_KUBERNETES = "Nano-Kubernetes";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:APP_NAME = "nano" + $env:ENVIRONMENT.ToLower() + "containerregistry";

# Register Providers
az provider register --namespace Microsoft.ContainerRegistry;

# Create Azure Container Registry (ACR)
$env:LOG_ANALYTICS_WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].id -o tsv;

az acr create `
  -g $env:AZURE_RESOURCE_GROUP_DELIVERY `
  -n $env:APP_NAME `
  -l $env:AZURE_LOCATION `
  --sku Standard `
  --workspace $env:LOG_ANALYTICS_WORKSPACE_ID `
  --admin-enabled false;

# Attach ACR to AKS
$env:CONTAINER_REGISTRY_ID = az acr show -g $env:AZURE_RESOURCE_GROUP_DELIVERY -n $env:APP_NAME --query id -o tsv;
$env:KUBERNETES_NAME = az aks list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES --query [0].name -o tsv;

az aks update `
  -n $env:KUBERNETES_NAME `
  -g $env:AZURE_RESOURCE_GROUP_KUBERNETES `
  --attach-acr $env:CONTAINER_REGISTRY_ID;
