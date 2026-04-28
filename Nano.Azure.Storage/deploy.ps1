$env:ENVIRONMENT = "";
$env:AZURE_RESOURCE_GROUP = "Nano-Storage";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:AZURE_RESOURCE_GROUP_BACKUP = "Nano-Backup";
$env:AZURE_LOCATION = "North Europe";
$env:APP_NAME = "nanostorage" + $env:ENVIRONMENT.ToLower();
$env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS = "";
$env:STORAGE_SKU = "Standard_LRS"; # Standard_ZRS

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

# Network Rules (Optional)
az storage account network-rule add `
    -n $env:APP_NAME `
    --ip-address $env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS;

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
