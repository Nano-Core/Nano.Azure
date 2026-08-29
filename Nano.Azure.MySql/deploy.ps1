$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "North Europe";
$env:AZURE_RESOURCE_GROUP = "Nano-Database";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:AZURE_RESOURCE_GROUP_KUBERNETES = "Nano-Kubernetes";
$env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS = "Nano-Kubernetes-Assets";
$env:MYSQL_VERSION = "8.4";
$env:MYSQL_SKU = "Standard_D2ads_v5";
$env:MYSQL_STORAGE_SIZE = "64";
$env:MYSQL_TIER = "GeneralPurpose";
$env:MYSQL_BACKUP_INTERVAL = 24
$env:MYSQL_BACKUP_RETENTION = 35
$env:MYSQL_PORT = 3306;
$env:APP_NAME = "nano-mysql-" + $env:ENVIRONMENT.ToLower();
$env:IDENTITY_NAME = $env:APP_NAME + "-identity";
$env:ADMIN_GROUP_NAME = $env:APP_NAME + "-admins";
$env:DEVELOPER_GROUP_NAME = $env:APP_NAME + "-developers";

# Register Providers
az provider register -n Microsoft.DBforMySQL;

az extension add --name rdbms-connect

# Resource Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Create MySql Server
az mysql flexible-server create `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION `
    --sku-name $env:MYSQL_SKU `
    --tier $env:MYSQL_TIER `
    --version $env:MYSQL_VERSION `
    --storage-auto-grow Enabled `
    --storage-size $env:MYSQL_STORAGE_SIZE `
    --database-port $env:MYSQL_PORT `
    --auto-scale-iops Enabled `
    --backup-retention $env:MYSQL_BACKUP_RETENTION `
    --backup-interval $env:MYSQL_BACKUP_INTERVAL `
    --public-access Disabled `
    --zone 1 `
    --geo-redundant-backup Enabled `
    --high-availability ZoneRedundant `
    --standby-zone 2 `
    -y;

# Managed Identity
az identity create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:IDENTITY_NAME;

$env:IDENTITY_PRINCIPAL_ID = az identity show -g $env:AZURE_RESOURCE_GROUP -n $env:IDENTITY_NAME --query principalId -o tsv;
$env:DIRECTORY_READERS_ROLE_ID = "88d8e3e3-8f55-4a1e-953a-9b9898b8876b";

az rest --method POST `
    --uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" `
    --body "{ \`"principalId\`": \`"$env:IDENTITY_PRINCIPAL_ID\`", \`"roleDefinitionId\`": \`"$env:DIRECTORY_READERS_ROLE_ID\`", \`"directoryScopeId\`": \`"/\`" }";

az mysql flexible-server identity assign `
    -g $env:AZURE_RESOURCE_GROUP `
    -s $env:APP_NAME `
    --identity $env:IDENTITY_NAME;

az ad group create `
    --display-name $env:ADMIN_GROUP_NAME `
    --mail-nickname $env:ADMIN_GROUP_NAME;

az ad group create `
    --display-name $env:DEVELOPER_GROUP_NAME `
    --mail-nickname $env:DEVELOPER_GROUP_NAME;

$env:ADMIN_GROUP_ID = az ad group show -g $env:ADMIN_GROUP_NAME --query id -o tsv;
$env:IDENTITY_PRINCIPAL_ID = az identity show -g $env:AZURE_RESOURCE_GROUP -n $env:IDENTITY_NAME --query principalId -o tsv;

az ad group member add `
    --group $env:ADMIN_GROUP_NAME `
    --member-id $env:IDENTITY_PRINCIPAL_ID;

$env:SERVICE_PRINCIPAL_NAME = "nano-deploy-service-principal";
$env:SERVICE_PRINCIPAL_OBJECT_ID = az ad sp list --display-name $env:SERVICE_PRINCIPAL_NAME --query "[0].id" -o tsv;

az ad group member add `
    --group $env:ADMIN_GROUP_NAME `
    --member-id $env:SERVICE_PRINCIPAL_OBJECT_ID;

az mysql flexible-server ad-admin create `
    -g $env:AZURE_RESOURCE_GROUP `
    -s $env:APP_NAME `
    --display-name $env:ADMIN_GROUP_NAME `
    --object-id $env:ADMIN_GROUP_ID `
    --identity $env:IDENTITY_NAME;

az mysql flexible-server parameter set `
    -g $env:AZURE_RESOURCE_GROUP `
    -s $env:APP_NAME `
    -n aad_auth_only `
    -v ON;

$env:USER_OBJECT_ID = az ad signed-in-user show --query id -o tsv;

az ad group member add `
    --group $env:ADMIN_GROUP_NAME `
    --member-id $env:USER_OBJECT_ID;

$env:MYSQL_USER = az ad signed-in-user show --query userPrincipalName -o tsv;
$env:MYSQL_TOKEN = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv;
$env:DEVELOPER_GROUP_ID = az ad group show -g $env:DEVELOPER_GROUP_NAME --query id -o tsv;
$env:DEVELOPER_GROUP_SQL_PATH = Join-Path $env:USERPROFILE "developer-group-user.sql";

Get-Content .sql/developer-group-user.sql | foreach { [Environment]::ExpandEnvironmentVariables($_) } | Set-Content $env:DEVELOPER_GROUP_SQL_PATH;

az mysql flexible-server execute `
    -n $env:APP_NAME `
    -u $env:ADMIN_GROUP_NAME `
    -p $env:MYSQL_TOKEN `
    --file-path $env:DEVELOPER_GROUP_SQL_PATH;

az ad group member remove `
    --group $env:ADMIN_GROUP_NAME `
    --member-id $env:USER_OBJECT_ID;

# Maintenance
az mysql flexible-server update `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --maintenance-window Sun:4:00;

# Parameters (Optional)
az mysql flexible-server parameter set `
    -g $env:AZURE_RESOURCE_GROUP `
    -s $env:APP_NAME `
    -n transaction_isolation `
    -v "READ-UNCOMMITTED";

# Diagnostics Settings
$env:DIAGNOSTIC_SETTINGS_NAME = "diagnostics-" + $env:APP_NAME;
$env:WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].[id] -o tsv;
$env:MYSQL_ID = az mysql flexible-server show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;

az monitor diagnostic-settings create `
    --name $env:DIAGNOSTIC_SETTINGS_NAME `
    --resource $env:MYSQL_ID `
    --workspace $env:WORKSPACE_ID `
    --logs '@.diagnostic-settings/logs.json' `
    --metrics '@.diagnostic-settings/metrics.json';

# Alert Rules
$env:MYSQL_ID = az mysql flexible-server show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
$env:ACTION_GROUP = az monitor action-group list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].[id] -o tsv;

az monitor metrics alert create `
    --name "High CPU Usage" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --scopes $env:MYSQL_ID `
    --condition "avg cpu_percent > 80" `
    --window-size PT5M `
    --evaluation-frequency PT1M `
    --action $env:ACTION_GROUP `
    --severity 2 `
    --description "Alert when CPU usage is above 80% for 5 minutes.";

az monitor metrics alert create `
    --name "High Memory Usage" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --scopes $env:MYSQL_ID `
    --condition "avg memory_percent > 80" `
    --window-size PT5M `
    --evaluation-frequency PT1M `
    --action $env:ACTION_GROUP `
    --severity 2 `
    --description "Alert when Memory usage is above 80% for 5 minutes.";

az monitor metrics alert create `
    --name "High Number Of Connections" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --scopes $env:MYSQL_ID `
    --condition "avg active_connections > 100" `
    --window-size PT5M `
    --evaluation-frequency PT1M `
    --action $env:ACTION_GROUP `
    --severity 2 `
    --description "Alert when the number of active connections exceeds 100 for 5 minutes.";

az monitor metrics alert create `
    --name "High Storage IO" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --scopes $env:MYSQL_ID `
    --condition "avg io_consumption_percent > 80" `
    --window-size PT5M `
    --evaluation-frequency PT1M `
    --action $env:ACTION_GROUP `
    --severity 2 `
    --description "Alert when Storage IO consumption is above 80% for 5 minutes.";

az monitor metrics alert create `
    --name "High Storage Percent" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --scopes $env:MYSQL_ID `
    --condition "avg storage_percent > 80" `
    --window-size PT5M `
    --evaluation-frequency PT1M `
    --action $env:ACTION_GROUP `
    --severity 2 `
    --description "Alert when Storage usage exceeds 80% for 5 minutes.";
  
# Network Rules.
$env:PRIVATE_LINK = "privatelink.mysql.database.azure.com";
$env:PRIVATE_ENDPOINT_NAME = $env:APP_NAME + "-private-endpoint";
$env:MYSQL_ID = az mysql flexible-server show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
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
    --group-id mysqlServer `
    --subnet $env:SUBNET_ID `
    --private-connection-resource-id $env:MYSQL_ID;

az network private-endpoint dns-zone-group create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:PRIVATE_ENDPOINT_NAME-dns-zone-group `
    --endpoint-name $env:PRIVATE_ENDPOINT_NAME `
    --private-dns-zone $env:PRIVATE_LINK `
    --zone-name mysql;
