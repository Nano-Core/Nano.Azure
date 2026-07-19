# Nano.Azure.Dns

> _DNS zone used for Kubernetes (AKS) domain management and service routing._  

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[DNS Zone](#dns-zone)**  
  * **[DNSSEC](#dnssec)**  
  * **[Managed Identity (Kubernetes)](#managed-identity-kubernetes)**  
  * **[External DNS Registrar Delegation](#external-dns-registrar-delegation)** 
* **[Multiple DNS Zone](#multiple-dns-zone)**  
* **[Dependencies](#dependencies)**  

## Summary
Azure DNS is a cloud-based Domain Name System service that provides reliable and secure DNS hosting and management for domain records. It enables the creation and control of DNS zones and 
records, supporting services such as domain resolution, subdomain delegation, and automated DNS record management. With built-in high availability, global redundancy, and integration with 
Azure identity and security services, Azure DNS ensures fast, resilient, and secure name resolution for applications and infrastructure.  

#### Azure DNS Architecture
![Nano Azure DNS Architecture](https://raw.githubusercontent.com/Nano-Core/Nano.Azure/master/.assets/Nano-Dns.jpg)

> 📖 Learn more about **[Azure DNS](https://learn.microsoft.com/en-us/azure/dns/dns-overview)**.

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

Add the resource group name as GitHub organization variables.  

| Secret                      | Type    | Description                                |
| --------------------------- | ------- |------------------------------------------- |
| `AZURE_RESOURCE_GROUP_DNS`  | vars    | The Azure resource group of the DNS Zone.  |

### DNS Zone
Creates the Azure DNS zone for the application domain, which will host all DNS records for the delegated subdomain and enable cert-manager DNS-01 validation.  

### DNSSEC
DNSSEC is enabled automatically when the DNS zone is created.

After enabling DNSSEC, Azure Portal displays the following warning under DNSSEC for the DNS zone:

> **DNSSEC is not fully configured for the DNS zone.**

This warning indicates that the DNSSEC chain of trust is not yet complete. Although DNSSEC has been enabled for the zone, the parent zone (typically managed by your domain registrar) has 
not been configured to trust it. 

To complete the chain of trust, you must create a **DS (Delegation Signer)** record in the parent zone or at your domain registrar. The required DS record values are available in Azure 
Portal under the DNSSEC settings for the DNS zone. Once the DS record has been added and propagated, the warning will disappear and the DNSSEC chain of trust will be fully established.

### Managed Identity (Kubernetes)
Creates a Managed Identity in Azure and assigns it the DNS Zone Contributor role on the DNS zone, allowing it to manage DNS records required for automated DNS-based operations such as domain 
validation and certificate issuance.  

### External DNS Registrar Delegation
At your external DNS provider (e.g., GoDaddy, Namecheap, or any domain registrar), you must delegate the subdomain to Azure DNS by creating NS (Name Server) records. This ensures that all DNS 
resolution for the subdomain is handled by Azure DNS instead of the external provider.  

Run the following command to get the Azure name servers. 

```powershell
az network dns zone show -g $env:AZURE_RESOURCE_GROUP -n $env:APP_DOMAIN_NAME --query nameServers -o tsv;
```

For each returned name server, add an NS record for the delegated subdomain.  

| Type | Host / Name           | Value             |
| ---- |---------------------- | ----------------- |
| NS   | $env:APP_DOMAIN_NAME  | {{name-server}}   |

## Multiple DNS Zone
Creating multiple DNS zones for different domain names is fully supported. Create each additional DNS zone as needed, but reuse the existing Managed Identity rather than creating a 
new one. Instead, add a new role assignment for the existing identity that grants access to the additional DNS zone.  

## Dependencies
DNS has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                   | Description                                                             | 
| ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.Account](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Account/README.md#nanoazureaccount)**  | The is the foundation or prerequites of the Nano Azure infrastructure.  |
