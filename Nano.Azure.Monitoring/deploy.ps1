$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "North Europe";
$env:AZURE_RESOURCE_GROUP = "Nano-Logs";
$env:APP_NAME_LOG_ANALYTCS = "nano-log-analytics-workspace-" + $env:ENVIRONMENT.ToLower();
$env:APP_NAME_MONITOR = "nano-monitor-workspace-" + $env:ENVIRONMENT.ToLower();
$env:WORKSPACE_SKU = "PerGB2018";
$env:ACTION_GROUP_NAME = "nano-monitor-action-group";

# Register Providers
az provider register --namespace microsoft.insights;
az provider register --namespace Microsoft.OperationalInsights;

# Resurce Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Log Analytics Workspace
az monitor log-analytics workspace create `
    -n $env:APP_NAME_LOG_ANALYTCS `
    -g $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION `
    --sku $env:WORKSPACE_SKU `
    --identity-type SystemAssigned `
    --retention-time 30;

# Monitor Workspace
az monitor account create `
    -g $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION `
    -n $env:APP_NAME_MONITOR;

# Application Insights
$env:APP_NAME_INSIGTHS = "app-insights-" + $env:ENVIRONMENT.ToLower();;
$env:WORKSPACE_ID = az monitor log-analytics workspace list -g $env:AZURE_RESOURCE_GROUP --query [0].id -o tsv;

az monitor app-insights component create `
    -a $env:APP_NAME_INSIGTHS `
    -l $env:AZURE_LOCATION `
    -g $env:AZURE_RESOURCE_GROUP `
    --query-access Disabled `
    --ingestion-access Disabled `
    --workspace $env:WORKSPACE_ID;

# Monitor Action Group
az monitor action-group create  `
    -n $env:ACTION_GROUP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --short-name monitor;

$env:MONITORING_READER_ROLE_ID = az role definition list --name "Monitoring Reader" --query [0].[name] -o tsv;
az monitor action-group update `
    -n $env:ACTION_GROUP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --add-action armrole "Monitoring Reader" $env:MONITORING_READER_ROLE_ID;

$env:MONITORING_CONTRIBUTOR_ROLE_ID = az role definition list --name "Monitoring Contributor" --query [0].[name] -o tsv;
az monitor action-group update `
    -n $env:ACTION_GROUP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --add-action armrole "Monitoring Contributor" $env:MONITORING_CONTRIBUTOR_ROLE_ID;
