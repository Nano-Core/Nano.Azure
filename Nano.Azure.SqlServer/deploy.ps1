$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "North Europe";
$env:AZURE_RESOURCE_GROUP = "Nano-Database";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS = "Nano-Kubernetes-Assets";
$env:SQL_ADMIN_USERNAME = "adminuser";
$env:SQL_ADMIN_PASSWORD = "";
$env:APP_NAME = "nano-sqlserver-" + $env:ENVIRONMENT.ToLower();

# Register Providers
az provider register -n Microsoft.Sql;

# Resource Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Create SQL Server
az sql server create `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION `
    --admin-user $env:SQL_ADMIN_USERNAME `
    --admin-password $env:SQL_ADMIN_PASSWORD `
    --enable-public-network false;

# Network Rules
$env:PRIVATE_LINK = "privatelink.database.windows.net";
$env:PRIVATE_ENDPOINT_NAME = $env:APP_NAME + "-private-endpoint";
$env:SQLSERVER_ID = az sql server show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
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
    --group-id sqlServer `
    --subnet $env:SUBNET_ID `
    --private-connection-resource-id $env:SQLSERVER_ID;

az network private-endpoint dns-zone-group create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:PRIVATE_ENDPOINT_NAME-dns-zone-group `
    --endpoint-name $env:PRIVATE_ENDPOINT_NAME `
    --private-dns-zone $env:PRIVATE_LINK `
    --zone-name sqlserver;