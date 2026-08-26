$env:SERVICE_PRINCIPAL_NAME = "nano-deploy-service-principal";
$env:AZURE_SUBSCRIPTION_ID_STAGING = "";
$env:AZURE_SUBSCRIPTION_ID_PRODUCTION = "";

$subscriptions = @(
    $env:AZURE_SUBSCRIPTION_ID_STAGING,
    $env:AZURE_SUBSCRIPTION_ID_PRODUCTION
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) };

$env:ASSIGNABLE_SCOPES = ($subscriptions | ForEach-Object { '"/subscriptions/{0}"' -f $_ }) -join ',';

## Service Principal
az ad sp create-for-rbac `
    --name $env:SERVICE_PRINCIPAL_NAME `
    --years 2;

# Custom Roles
$env:STORAGE_ROLE_NAME = "Restricted User Access Administrator (Storage)";
$env:STORAGE_ROLE_PATH = Join-Path $env:USERPROFILE "$env:STORAGE_ROLE_NAME.json";
Get-Content .roles/$env:STORAGE_ROLE_NAME.json | foreach { [Environment]::ExpandEnvironmentVariables($_) } | Set-Content $env:STORAGE_ROLE_PATH;

az role definition create --role-definition $env:STORAGE_ROLE_PATH;

# Role Assignments
$env:APP_ID = az ad sp list --display-name $env:SERVICE_PRINCIPAL_NAME --query "[0].appId" -o tsv;

foreach ($subscriptionId in $subscriptions) {
    az role assignment create `
        --assignee $env:APP_ID `
        --role "Contributor" `
        --scope "/subscriptions/$subscriptionId";

    az role assignment create `
        --assignee $env:APP_ID `
        --role "Resource Policy Contributor" `
        --scope "/subscriptions/$subscriptionId";

    az role assignment create `
        --assignee $env:APP_ID `
        --role $env:STORAGE_ROLE_NAME `
        --scope "/subscriptions/$subscriptionId" `
        --condition-version "2.0" `
        --condition "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR ((@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {a235d3ee-5935-4cfb-8cc5-a3303ad5995e}) AND (@Request[Microsoft.Authorization/roleAssignments:PrincipalType] StringEqualsIgnoreCase 'ServicePrincipal')))";
}
