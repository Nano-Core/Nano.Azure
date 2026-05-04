$env:ENVIRONMENT = "";
$env:AZURE_RESOURCE_GROUP = "Nano-Storage";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:AZURE_RESOURCE_GROUP_BACKUP = "Nano-Backup";
$env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS = "Nano-Kubernetes-Assets";
$env:AZURE_LOCATION = "North Europe";
$env:STORAGE_SKU = "Standard_LRS";
$env:APP_NAME = "nanostorage" + $env:ENVIRONMENT.ToLower();

# Register Providers
az provider register -n Microsoft.Storage;

# Resource Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Storage Account
az storage account create `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION `
    --sku $env:STORAGE_SKU `
    --kind StorageV2 `
    --default-action Deny `
    --https-only true `
    --access-tier Hot `
    --enable-large-file-share `
    --public-network-access Disabled `
    --allow-blob-public-access false `
    --min-tls-version TLS1_2 `
    --require-infrastructure-encryption;

# Backup Policy
$env:STORAGE_ACCOUNT_BACKUP_POLICY_NAME = $env:APP_NAME + "-backup-policy";
$env:BACKUP_VAULT_NAME = az backup vault list --query "[0].name" -o tsv;

az backup policy create `
    -n $env:STORAGE_ACCOUNT_BACKUP_POLICY_NAME `
    -g $env:AZURE_RESOURCE_GROUP_BACKUP `
    --vault-name $env:BACKUP_VAULT_NAME `
    --backup-management-type AzureStorage `
    --workload-type AzureFileShare `
    --policy .backup-policies/storage-backup-policy.json;

# Diagnostic Settings
$env:DIAGNOSTIC_SETTINGS_NAME = "diagnostics-" + $env:APP_NAME;
$env:WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query "[0].[id]" -o tsv;
$env:STORAGE_ACCOUNT_ID = az storage account list --query "[?name =='$env:APP_NAME'].[id]" -o tsv;

az monitor diagnostic-settings create `
    -n $env:DIAGNOSTIC_SETTINGS_NAME `
    --workspace $env:WORKSPACE_ID `
    --resource $env:STORAGE_ACCOUNT_ID `
    --metrics '@.diagnostic-settings/metrics.json';

az monitor diagnostic-settings create `
    -n $env:DIAGNOSTIC_SETTINGS_NAME `
    --workspace $env:WORKSPACE_ID `
    --resource $env:STORAGE_ACCOUNT_ID/fileServices/default `
    --logs '@.diagnostic-settings/file/logs.json' `
    --metrics '@.diagnostic-settings/file/metrics2.json';

# Alert Rules
$env:STORAGE_ACCOUNT_ID = az storage account list -g $env:AZURE_RESOURCE_GROUP --query "[?name =='$env:APP_NAME'].[id]" -o tsv;
$env:ACTION_GROUP = az monitor action-group list -g $env:AZURE_RESOURCE_GROUP_LOGS --query "[0].[id]" -o tsv;

az monitor metrics alert create `
  --name "High Transaction Count" `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:STORAGE_ACCOUNT_ID `
  --condition "total transactions > 1000" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 2 `
  --description "Alert when transaction count exceeds 1000 for 5 minutes.";

az monitor metrics alert create `
  --name "Low Availability" `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:STORAGE_ACCOUNT_ID `
  --condition "avg availability < 99.9" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 2 `
  --description "Alert when availability drops below 99.9% for 5 minutes.";

az monitor metrics alert create `
  --name "High Latency" `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:STORAGE_ACCOUNT_ID `
  --condition "avg SuccessE2ELatency > 200" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 2 `
  --description "Alert when End-to-End latency exceeds 200ms for 5 minutes.";

az monitor metrics alert create `
  --name "High Egress" `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scopes $env:STORAGE_ACCOUNT_ID `
  --condition "avg egress > 1000" `
  --window-size PT5M `
  --evaluation-frequency PT1M `
  --action $env:ACTION_GROUP `
  --severity 2 `
  --description "Alert when egress exceeds 1000MB for 5 minutes.";

# Network Rules.
$env:PRIVATE_LINK = "privatelink.file.core.windows.net";
$env:PRIVATE_ENDPOINT_NAME = $env:APP_NAME + "-private-endpoint";
$env:STORAGE_ACCOUNT_ID = az storage account list -g $env:AZURE_RESOURCE_GROUP --query "[?name =='$env:APP_NAME'].[id]" -o tsv;
$env:VNET_ID = az network vnet list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS --query [0].id -o tsv;
$env:SUBNET_ID = az network vnet subnet list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES_ASSETS --vnet-name $env:VNET_NAME --query [0].id -o tsv;

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
  --name $env:PRIVATE_ENDPOINT_NAME `
  --connection-name $env:PRIVATE_ENDPOINT_NAME-connection `
  --nic-name $env:PRIVATE_ENDPOINT_NAME-nic `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --group-id file `
  --subnet $env:SUBNET_ID `
  --private-connection-resource-id $env:STORAGE_ACCOUNT_ID;

az network private-endpoint dns-zone-group create `
  -g $env:AZURE_RESOURCE_GROUP `
  -n $env:PRIVATE_ENDPOINT_NAME-dns-zone-group `
  --endpoint-name $env:PRIVATE_ENDPOINT_NAME `
  --private-dns-zone $env:PRIVATE_LINK `
  --zone-name file;
