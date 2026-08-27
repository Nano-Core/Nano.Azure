$env:SERVICE_PRINCIPAL_NAME = "nano-deploy-service-principal";
$env:AZURE_SUBSCRIPTION_ID_STAGING = "";
$env:AZURE_SUBSCRIPTION_ID_PRODUCTION = "";

$subscriptions = @(
    $env:AZURE_SUBSCRIPTION_ID_STAGING,
    $env:AZURE_SUBSCRIPTION_ID_PRODUCTION
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) };

## Service Principal
az ad sp create-for-rbac `
    --name $env:SERVICE_PRINCIPAL_NAME `
    --years 2;

# Role Assignments
$env:APP_ID = az ad sp list --display-name $env:SERVICE_PRINCIPAL_NAME --query "[0].appId" -o tsv;

foreach ($subscriptionId in $subscriptions) 
{
    az role assignment create `
        --assignee $env:APP_ID `
        --role "Contributor" `
        --scope "/subscriptions/$subscriptionId";

    az role assignment create `
        --assignee $env:APP_ID `
        --role "Resource Policy Contributor" `
        --scope "/subscriptions/$subscriptionId";
}
