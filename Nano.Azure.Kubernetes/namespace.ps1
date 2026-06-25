$env:AZURE_RESOURCE_GROUP_KUBERNETES = "Nano-Kubernetes";
$env:KUBERNETES_NAMESPACE = "apps";

# Namespace
$env:KUBERNETES_NAME = az aks list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES --query [0].name -o tsv;

az aks command invoke `
    -g $env:AZURE_RESOURCE_GROUP_KUBERNETES `
    -n $env:KUBERNETES_NAME `
    -c "kubectl create namespace $env:KUBERNETES_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -";

$env:NETWORK_POLICY_PATH = Join-Path $env:USERPROFILE "network-policy-namespace.yaml";
Get-Content .kubernetes/network-policy-namespace.yaml | foreach { [Environment]::ExpandEnvironmentVariables($_) } | Set-Content $env:NETWORK_POLICY_PATH;

az aks command invoke `
    -g $env:AZURE_RESOURCE_GROUP_KUBERNETES `
    -n $env:KUBERNETES_NAME `
    --file $env:NETWORK_POLICY_PATH `
    -c "kubectl apply -f network-policy-namespace.yaml";
