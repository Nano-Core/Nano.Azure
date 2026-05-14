$env:ENVIRONMENT = "";
$env:AZURE_LOCATION = "Sweden Central";
$env:AZURE_RESOURCE_GROUP = "Nano-Dns";
$env:AZURE_RESOURCE_GROUP_KUBERNETES = "Nano-Kubernetes";
$env:KUBERNETES_NAMESPACE = "apps";
$env:APP_NAME = "dns-zone"; 
$env:APP_DOMAIN_NAME = ""; 

# Register Providers
az provider register --namespace Microsoft.Network;

# Resurce Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Dns Zone
az network dns zone create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_DOMAIN_NAME;

# Managed Identity (Kubernetes)
$env:APP_NAME_IDENTITY = $env:APP_NAME + "-identity";

az identity create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME_IDENTITY;

$env:DNS_ZONE_ID = az network dns zone show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_DOMAIN_NAME --query id -o tsv;
$env:PRINCIPAL_ID = az identity show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME_IDENTITY --query principalId -o tsv;
$env:AZURE_CLIENT_ID = az identity show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME_IDENTITY --query clientId -o tsv;

az role assignment create `
    --assignee-object-id $env:PRINCIPAL_ID `
    --assignee-principal-type ServicePrincipal `
    --role "DNS Zone Contributor" `
    --scope $env:DNS_ZONE_ID;

$env:APP_NAME_SERVICE_ACCOUNT = $env:APP_NAME + "-service-account";
$env:KUBERNETES_NAME = az aks list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES --query [0].name -o tsv;
$env:KUBERNETES_ISSUER_URL = az aks list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES --query [0].['oidcIssuerProfile.issuerUrl'] -o tsv;
$env:SERVICE_ACCOUNT_PATH = Join-Path $env:USERPROFILE serviceaccount.yaml;

Get-Content .kubernetes/serviceaccount.yaml | foreach { [Environment]::ExpandEnvironmentVariables($_) } | Set-Content $env:SERVICE_ACCOUNT_PATH;

az aks command invoke `
    -g $env:AZURE_RESOURCE_GROUP_KUBERNETES `
    -n $env:KUBERNETES_NAME `
    --file $env:SERVICE_ACCOUNT_PATH `
    -c "kubectl apply -f serviceaccount.yaml";

$env:SUBJECT = "system:serviceaccount:" + $env:KUBERNETES_NAMESPACE + ":" + $env:APP_NAME_SERVICE_ACCOUNT

az identity federated-credential create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME_IDENTITY-federation `
    --identity-name $env:APP_NAME_IDENTITY `
    --issuer $env:KUBERNETES_ISSUER_URL `
    --subject $env:SUBJECT;
