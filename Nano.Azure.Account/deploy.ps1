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
