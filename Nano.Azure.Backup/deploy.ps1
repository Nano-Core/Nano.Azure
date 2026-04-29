$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "North Europe";
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
    --cross-subscription-restore-state Disable `
    --immutability-state Unlocked ` 
    --job-failure-alerts Enable;

az backup vault backup-properties set `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --backup-storage-redundancy LocallyRedundant;

# Diagnostics Settings
$env:DIAGNOSTIC_SETTINGS_NAME = "diagnostics-" + $env:APP_NAME;
$env:WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP_LOGS --query "[0].[id]" -o tsv;
$env:BACKUP_ID = az backup vault list --query "[?name == '$env:APP_NAME'].id" -o tsv;

az monitor diagnostic-settings create `
    --name $env:DIAGNOSTIC_SETTINGS_NAME `
    --workspace $env:WORKSPACE_ID `
    --resource $env:BACKUP_ID `
    --metrics '@.diagnostic-settings/metrics.json';
