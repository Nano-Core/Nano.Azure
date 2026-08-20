$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "North Europe";
$env:AZURE_RESOURCE_GROUP = "Nano-Database";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS = "Nano-Kubernetes-Assets";
$env:POSTGRESQL_VERSION = "16";
$env:POSTGRESQL_SKU = "Standard_D2ads_v5";
$env:POSTGRESQL_STORAGE_SIZE = "64";
$env:POSTGRESQL_TIER = "GeneralPurpose";
$env:POSTGRESQL_BACKUP_INTERVAL = 24
$env:POSTGRESQL_BACKUP_RETENTION = 35
$env:POSTGRESQL_ADMIN_USERNAME = "adminuser";
$env:POSTGRESQL_ADMIN_PASSWORD = "";
$env:APP_NAME = "nano-postgresql-" + $env:ENVIRONMENT.ToLower();

# Register Providers
az provider register -n Microsoft.DBforPostgreSQL;

# Resource Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Create PostgreSQL Server
az postgres flexible-server create `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION `
    --sku-name $env:POSTGRESQL_SKU `
    --tier $env:POSTGRESQL_TIER `
    --version $env:POSTGRESQL_VERSION `
    --storage-auto-grow Enabled `
    --storage-size $env:POSTGRESQL_STORAGE_SIZE `
    --auto-grow Enabled `
    --backup-retention $env:POSTGRESQL_BACKUP_RETENTION `
    --admin-user $env:POSTGRESQL_ADMIN_USERNAME `
    --admin-password $env:POSTGRESQL_ADMIN_PASSWORD `
    --public-access Disabled `
    --zone 1 `
    --geo-redundant-backup Enabled `
    --high-availability ZoneRedundant `
    --standby-zone 2 `
    -y;

# Maintenance
az postgres flexible-server update `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --maintenance-window Sun:4:00;

# Diagnostics Settings
$env:DIAGNOSTIC_SETTINGS_NAME = "diagnostics-" + $env:APP_NAME;
$env:WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].[id] -o tsv;
$env:POSTGRESQL_ID = az postgres flexible-server show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;

az monitor diagnostic-settings create `
    --name $env:DIAGNOSTIC_SETTINGS_NAME `
    --resource $env:POSTGRESQL_ID `
    --workspace $env:WORKSPACE_ID `
    --logs '@.diagnostic-settings/logs.json' `
    --metrics '@.diagnostic-settings/metrics.json';

# Alert Rules
$env:POSTGRESQL_ID = az postgres flexible-server show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
$env:ACTION_GROUP = az monitor action-group list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].[id] -o tsv;

az monitor metrics alert create `
    --name "High CPU Usage" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --scopes $env:POSTGRESQL_ID `
    --condition "avg cpu_percent > 80" `
    --window-size PT5M `
    --evaluation-frequency PT1M `
    --action $env:ACTION_GROUP `
    --severity 2 `
    --description "Alert when CPU usage is above 80% for 5 minutes.";

az monitor metrics alert create `
    --name "High Memory Usage" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --scopes $env:POSTGRESQL_ID `
    --condition "avg memory_percent > 80" `
    --window-size PT5M `
    --evaluation-frequency PT1M `
    --action $env:ACTION_GROUP `
    --severity 2 `
    --description "Alert when Memory usage is above 80% for 5 minutes.";

az monitor metrics alert create `
    --name "High Number Of Connections" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --scopes $env:POSTGRESQL_ID `
    --condition "avg active_connections > 100" `
    --window-size PT5M `
    --evaluation-frequency PT1M `
    --action $env:ACTION_GROUP `
    --severity 2 `
    --description "Alert when the number of active connections exceeds 100 for 5 minutes.";

az monitor metrics alert create `
    --name "High Storage IO" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --scopes $env:POSTGRESQL_ID `
    --condition "avg io_consumption_percent > 80" `
    --window-size PT5M `
    --evaluation-frequency PT1M `
    --action $env:ACTION_GROUP `
    --severity 2 `
    --description "Alert when Storage IO consumption is above 80% for 5 minutes.";

az monitor metrics alert create `
    --name "High Storage Percent" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --scopes $env:POSTGRESQL_ID `
    --condition "avg storage_percent > 80" `
    --window-size PT5M `
    --evaluation-frequency PT1M `
    --action $env:ACTION_GROUP `
    --severity 2 `
    --description "Alert when Storage usage exceeds 80% for 5 minutes.";

# Network Rules.
$env:PRIVATE_LINK = "privatelink.postgres.database.azure.com";
$env:PRIVATE_ENDPOINT_NAME = $env:APP_NAME + "-private-endpoint";
$env:POSTGRESQL_ID = az postgres flexible-server show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
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
    --group-id postgresqlServer `
    --subnet $env:SUBNET_ID `
    --private-connection-resource-id $env:POSTGRESQL_ID;

az network private-endpoint dns-zone-group create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:PRIVATE_ENDPOINT_NAME-dns-zone-group `
    --endpoint-name $env:PRIVATE_ENDPOINT_NAME `
    --private-dns-zone $env:PRIVATE_LINK `
    --zone-name postgres;