$env:AZURE_RESOURCE_GROUP_KUBERNETES = "Nano-Kubernetes";
$env:CONTAINER_REGISTRY_HOST = "ghcr.io/{{organization-name}}";
$env:CONTAINER_REGISTRY_USERNAME = "";
$env:CONTAINER_REGISTRY_PASSWORD = "";

# Image Pull Secret
$env:KUBERNETES_NAME = az aks list -g $env:AZURE_RESOURCE_GROUP_KUBERNETES --query [0].name -o tsv;

az aks command invoke `
  -g $env:AZURE_RESOURCE_GROUP_KUBERNETES `
  -n $env:KUBERNETES_NAME `
  --file $env:STORAGE_CLASS_PATH `
  -c "kubectl create secret docker-registry ghcr-pull-secret `
      --docker-server=$env:CONTAINER_REGISTRY_HOST `
      --docker-username=$env:CONTAINER_REGISTRY_USERNAME `
      --docker-password=$env:CONTAINER_REGISTRY_PASSWORD";
