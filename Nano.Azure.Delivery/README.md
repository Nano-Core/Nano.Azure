# Nano.Azure.ContainerApps

> _._  

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[Internal Only](#)**  
  * **[Internal Only](#)**  
  * **[Internal Only](#)**  
  * **[Internal Only](#)**  
* **[Multiple DNS Zone](#multiple-dns-zone)**  
* **[Dependencies](#dependencies)**  

## Summary

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

Add the resource group name as GitHub organization variables.  

| Secret                           | Type    | Description                                       |
| -------------------------------- | ------- |-------------------------------------------------- |
| `AZURE_RESOURCE_GROUP_DELIVERY`  | vars    | The Continious integration Azure resource group.  |
