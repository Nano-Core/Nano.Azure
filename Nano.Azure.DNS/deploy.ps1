$env:AZURE_LOCATION = "North Europe";
$env:AZURE_RESOURCE_GROUP = "Nano-Dns";
$env:APP_NAME = "dns-zone"; 
$env:DOMAIN_NAME = "live.nano-ignite.com"; 

# Register Providers
az provider register --namespace Microsoft.Network;

# Resurce Group
az group create `
    -n $env:AZURE_RESOURCE_GROUP `
    -l $env:AZURE_LOCATION;

# Dns Zone
az network dns zone create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:DOMAIN_NAME;

# DNSSEC
az network dns dnssec-config create `
    -g $env:AZURE_RESOURCE_GROUP `
    -z $env:DOMAIN_NAME;

# Managed Identity (Kubernetes)
$env:APP_NAME_IDENTITY = $env:APP_NAME + "-identity";

az identity create `
    -g $env:AZURE_RESOURCE_GROUP `
    -n $env:APP_NAME_IDENTITY;

$env:DNS_ZONE_ID = az network dns zone show -g $env:AZURE_RESOURCE_GROUP -n $env:DOMAIN_NAME --query id -o tsv;
$env:PRINCIPAL_ID = az identity show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_NAME_IDENTITY --query principalId -o tsv;

az role assignment create `
    --assignee-object-id $env:PRINCIPAL_ID `
    --assignee-principal-type ServicePrincipal `
    --role "DNS Zone Contributor" `
    --scope $env:DNS_ZONE_ID;
