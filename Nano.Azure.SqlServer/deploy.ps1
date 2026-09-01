$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "Sweden Central";
$env:AZURE_RESOURCE_GROUP = "Nano-Database";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS = "Nano-Kubernetes-Assets";
$env:APP_NAME = "nano-sqlserver-" + $env:ENVIRONMENT.ToLower();
$env:IDENTITY_NAME = $env:APP_NAME + "-identity";
$env:ADMIN_GROUP_NAME = $env:APP_NAME + "-admins";
$env:DEVELOPER_GROUP_NAME = $env:APP_NAME + "-developers";

# Register Providers
az provider register -n Microsoft.Sql;

az extension add --name rdbms-connect

# Resource Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Create SQL Server
$env:SQL_ADMIN_USERNAME = "sqladmin";
$env:SQL_ADMIN_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ });

az sql server create `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION `
    --admin-user $env:SQL_ADMIN_USERNAME `
    --admin-password $env:SQL_ADMIN_PASSWORD `
    --enable-public-network false;

# Managed Identity
az identity create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:IDENTITY_NAME;

$env:IDENTITY_ID = az identity show -g $env:AZURE_RESOURCE_GROUP -n $env:IDENTITY_NAME --query id -o tsv;
$env:IDENTITY_PRINCIPAL_ID = az identity show -g $env:AZURE_RESOURCE_GROUP -n $env:IDENTITY_NAME --query principalId -o tsv;
$env:DIRECTORY_READERS_ROLE_ID = "88d8e3e3-8f55-4a1e-953a-9b9898b8876b";

az rest --method POST `
    --uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" `
    --body "{ \`"principalId\`": \`"$env:IDENTITY_PRINCIPAL_ID\`", \`"roleDefinitionId\`": \`"$env:DIRECTORY_READERS_ROLE_ID\`", \`"directoryScopeId\`": \`"/\`" }";

az sql server update `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME `
    --assign_identity `
    --identity-type UserAssigned `
    --user-assigned-identity-id $env:IDENTITY_ID `
    --primary-user-assigned-identity-id $env:IDENTITY_ID;

az ad group create `
    --display-name $env:ADMIN_GROUP_NAME `
    --mail-nickname $env:ADMIN_GROUP_NAME;

az ad group create `
    --display-name $env:DEVELOPER_GROUP_NAME `
    --mail-nickname $env:DEVELOPER_GROUP_NAME;

$env:IDENTITY_PRINCIPAL_ID = az identity show -g $env:AZURE_RESOURCE_GROUP -n $env:IDENTITY_NAME --query principalId -o tsv;

az ad group member add `
    --group $env:ADMIN_GROUP_NAME `
    --member-id $env:IDENTITY_PRINCIPAL_ID;

$env:SERVICE_PRINCIPAL_NAME = "nano-deploy-service-principal";
$env:SERVICE_PRINCIPAL_OBJECT_ID = az ad sp list --display-name $env:SERVICE_PRINCIPAL_NAME --query "[0].id" -o tsv;

az ad group member add `
    --group $env:ADMIN_GROUP_NAME `
    --member-id $env:SERVICE_PRINCIPAL_OBJECT_ID;

$env:ADMIN_GROUP_ID = az ad group show -g $env:ADMIN_GROUP_NAME --query id -o tsv;

az sql server ad-admin create `
    -g $env:AZURE_RESOURCE_GROUP `
    -s $env:APP_NAME `
    --display-name $env:ADMIN_GROUP_NAME `
    --object-id $env:ADMIN_GROUP_ID;

az sql server ad-only-auth disable `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME;

$env:USER_OBJECT_ID = az ad signed-in-user show --query id -o tsv;

az ad group member add `
    --group $env:ADMIN_GROUP_NAME `
    --member-id $env:USER_OBJECT_ID;

$env:SQL_TOKEN = az account get-access-token --resource "https://database.windows.net/" --query accessToken -o tsv;
$env:DEVELOPER_GROUP_SQL_PATH = Join-Path $env:USERPROFILE "developer-group-user.sql";

Get-Content .sql/developer-group-user.sql | foreach { [Environment]::ExpandEnvironmentVariables($_) } | Set-Content $env:DEVELOPER_GROUP_SQL_PATH;

winget install sqlcmd

& "C:\Program Files\sqlcmd\sqlcmd.exe" `
    -S "$env:APP_NAME.database.windows.net" `
    -d master `
    --authentication-method ActiveDirectoryDefault `
    -i $env:DEVELOPER_GROUP_SQL_PATH;

az ad group member remove `
    --group $env:ADMIN_GROUP_NAME `
    --member-id $env:USER_OBJECT_ID;

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