# Nano.Azure.ContainerRegistry.Cleanup

> _Container registry (ACR) container image cleanup job._  

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
* **[Dependencies](#dependencies)**  

## Summary
This job performs automated cleanup of Azure Container Registry (ACR) images by removing old tags per repository.  

For each repository in the registry, it retrieves all tags ordered by creation time (newest first), keeps the most recent N tags (defined by `IMAGE_HISTORY_COUNT`), and deletes the remaining 
older images. This helps control registry size and cost by enforcing a simple retention policy across all repositories.  

## Registration
This deployment is executed as a GitHub scheduled workflow and runs once every 24 hours.  

It is configured as a matrix job, allowing execution across all target environments in parallel.  

## Dependencies
Container Registry has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                                                  | Description                                                             | 
| ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.ContainerRegistry](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.ContainerRegistry/README.md#nanoazureContainerregistry)**   | The Azure Container Regsitry (ACR) .                                    |
