$env:AZURE_SUBSCRIPTION_ID_STAGING = "";
$env:AZURE_SUBSCRIPTION_ID_PRODUCTION = "";
$env:SERVICE_PRINCIPAL_NAME = "nano-deploy-service-principal";

## Service Principal
az ad sp create-for-rbac `
    --name $env:SERVICE_PRINCIPAL_NAME `
    --role Contributor `
    --scope `
        "/subscriptions/$env:AZURE_SUBSCRIPTION_ID_STAGING" `
        "/subscriptions/$env:AZURE_SUBSCRIPTION_ID_PRODUCTION" `
    --years 2;

$env:APP_ID = az ad sp list --display-name $env:SERVICE_PRINCIPAL_NAME --query "[0].appId" -o tsv;

az role assignment create `
    --assignee $env:APP_ID `
    --role "Resource Policy Contributor" `
    --scope "/subscriptions/$env:AZURE_SUBSCRIPTION_ID_STAGING";

az role assignment create `
    --assignee $env:APP_ID `
    --role "Resource Policy Contributor" `
    --scope "/subscriptions/$env:AZURE_SUBSCRIPTION_ID_PRODUCTION";