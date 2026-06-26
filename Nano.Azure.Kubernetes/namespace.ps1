$env:AZURE_RESOURCE_GROUP_KUBERNETES = "Nano-Kubernetes";
$env:KUBERNETES_NAMESPACE = "apps";

# Namespace
$env:KUBERNETES_NAME = az aks list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES --query [0].name -o tsv;

az aks command invoke `
    -g $env:AZURE_RESOURCE_GROUP_KUBERNETES `
    -n $env:KUBERNETES_NAME `
    -c "kubectl create namespace $env:KUBERNETES_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -";
