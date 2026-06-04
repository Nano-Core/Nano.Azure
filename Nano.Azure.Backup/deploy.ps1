$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "Sweden Central";
$env:AZURE_RESOURCE_GROUP = "Nano-Backup";
$env:AZURE_RESOURCE_GROUP_LOGS = "Nano-Logs";
$env:APP_NAME = "nano-backup-vault-" + $env:ENVIRONMENT.ToLower();

# Register Providers
az provider register --namespace Microsoft.RecoveryServices;

# Resource Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Backup Vault
az backup vault create `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION `
    --immutability-state Unlocked `
    --job-failure-alerts Enable `
    --cross-subscription-restore-state Enable `
    --classic-alerts Disable `
    --public-network-access Disable;

# Data Redundancy
az backup vault backup-properties set `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --backup-storage-redundancy ZoneRedundant;

# Immutability State (Optional)
az backup vault update `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --immutability-state Locked;

# Diagnostics Settings
$env:BACKUP_ID = az backup vault show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
$env:DIAGNOSTIC_SETTINGS_NAME = "diagnostics-" + $env:APP_NAME;
$env:WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].[id] -o tsv;

az monitor diagnostic-settings create `
    --name $env:DIAGNOSTIC_SETTINGS_NAME `
    --workspace $env:WORKSPACE_ID `
    --resource $env:BACKUP_ID `
    --logs '@.diagnostic-settings/logs.json' `
    --metrics '@.diagnostic-settings/metrics.json';

# Alerts
$env:BACKUP_ID = az backup vault show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv;
$env:AZURE_RESOURCE_GROUP_ID = az group show -n $env:AZURE_RESOURCE_GROUP --query id -o tsv;
$env:ACTION_GROUP = az monitor action-group list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].[id] -o tsv;
$env:WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query [0].[id] -o tsv;

az monitor alert-processing-rule create `
  --name 'Backup Alert Processing Rule ' `
  --resource-group $env:AZURE_RESOURCE_GROUP `
  --scope $env:BACKUP_ID `
  --rule-type AddActionGroups `
  --action-groups $env:ACTION_GROUP `
  --enabled true;
