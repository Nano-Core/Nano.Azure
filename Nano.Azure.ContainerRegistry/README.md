# Nano.Azure.ContainerRegistry

> _Container registry (ACR) attached to Kubernetes._  

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Agent Pool](#agent-pool)**  
  * **[Attach Registry to Kubernetes](#attach-registry-to-kubernetes)**  
  * **[Network Rules](#network-rules)**  
* **[Dependencies](#dependencies)**  

## Summary
Azure Container Registry (ACR) is a private registry for storing and managing container images used by applications running in Kubernetes. By attaching the registry to the AKS cluster, 
Kubernetes can securely pull images without requiring additional image pull secrets or credentials.  

This deployment creates the registry and configures the integration with the existing Kubernetes environment.

#### Azure Architecture
![Nano Kubernetes Architecture](https://raw.githubusercontent.com/Nano-Core/Nano.Azure/v10.0.0-ga/.assets/Nano-ContainerRegistry.jpg)

## Registration
Start by registering the required Azure resource providers by executing the first part of the `deploy.ps1` script.

Once the providers have been registered, continue running the remainder of the script to create the Azure Container Registry and attach it to the Kubernetes cluster.

Since the registry is configured with admin credentials disabled, standard registry credentials cannot be used. To authenticate locally for image pull and push operations, sign in to Azure and 
then authenticate to the container registry using Azure CLI.

```powershell
az login
az acr login -n $env:ACR_NAME
```

### Agent Pool


if you are building often, you might want to increase the replica count to avoi delays in build queues on ACR



### Attach Registry to Kubernetes
The container registry is integrated directly with the Kubernetes cluster using AKS–ACR integration. This means workloads can pull images from the registry without requiring any manual 
authentication setup in Kubernetes manifests.  

Because of this integration, there is no need to define `imagePullSecrets` in deployment specifications.  

```yaml
imagePullSecrets:
  - name: pull-secret
```

## Network Rules
The container registry has public network access disabled by default.

A Private Endpoint is created within the Kubernetes virtual network, enabling applications running in the cluster to securely access the Storage Account file shares over a private 
connection.

To list the available `--group-id` values for use with the `az network private-endpoint create` command, run the following command.  

```powershell
az network private-link-resource list --id $env:ACR_ID;
```

> ⚠️ The private endpoint must be deployed in the same Azure region as the virtual network (VNet) it is associated with.

Optionally, IP address whitelisting can be configured to allow access to the container registry. By default, access is fully restricted, and no external connections are permitted. 
The Nano system does not depend on IP whitelisting for connectivity, and using it is generally discouraged as it can negatively impact the overall cloud security score. If IP 
whitelisting is required, it can be configured using the following command.  

> ⚠️ Whitelisting IP addresses can reduce the overall security posture and negatively impact the security score.  

## Dependencies
Container Registry has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.Delivery](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Delivery/README.md#nanoazuredelivery)**        | The Azure Kubernetes Delivery components.                                                    |
| **[Nano.Azure.Kubernetes](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Kubernetes/README.md#nanoazurekubernetes)**  | The Azure Kubernetes Service (AKS).                                           |
