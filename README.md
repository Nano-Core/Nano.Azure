# Nano.Azure

> _Cloud-native Azure services, infrastructure components, and deployment assets for Nano applications._

***

## Table of Contents
&nbsp;&nbsp;&nbsp;&nbsp;📌 **[Summary](#-summary)**  
&nbsp;&nbsp;&nbsp;&nbsp;⚙️ **[Required Tools](#-required-tools)**  

### Documentaion
&nbsp;&nbsp;&nbsp;&nbsp;🔹 **[Nano.Azure](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Account/README.md#nanoazureaccount)**    
&nbsp;&nbsp;&nbsp;&nbsp;🔹 **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**    
&nbsp;&nbsp;&nbsp;&nbsp;🔹 **[Nano.Azure.Backup](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Backup/README.md#nanoazurebackup)**  
&nbsp;&nbsp;&nbsp;&nbsp;🔹 **[Nano.Azure.Kubernetes](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Kubernetes/README.md#nanoazurekubernetes)**    
&nbsp;&nbsp;&nbsp;&nbsp;🔹 **[Nano.Azure.Storage](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Storage/README.md#nanoazurestorage)**    
&nbsp;&nbsp;&nbsp;&nbsp;🔹 **[Nano.Azure.MySql](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.MySql/README.md#nanoazuremysql)**    
&nbsp;&nbsp;&nbsp;&nbsp;🔹 **[Nano.Azure.PostgreSql](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.PostgreSql/README.md#nanoazurepostgresql)**    
&nbsp;&nbsp;&nbsp;&nbsp;🔹 **[Nano.Azure.SqlServer](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.SqlServer/README.md#nanoazuresqlserver)**    

## 📌 Summary
Nano.Azure provides a curated set of Azure services, infrastructure components, and deployment scripts designed to support 
**[Nano Applications](https://github.com/Nano-Core/Nano.Library/blob/master/README.md#nanolibrary)**. The goal is to standardize how Nano applications are hosted and operated 
in Azure by providing:

- Pre-configured infrastructure patterns
- Managed service first architecture
- Reusable deployment components
- Opinionated but flexible cloud setup

This repository focuses on leveraging _Azure managed services_ to reduce operational overhead, improve scalability, and simplify maintenance across environments. The key principles
in the Nano infrastructure are:

- Managed-first architecture – prefer Azure-managed services over self-hosted infrastructure  
- Consistency over configuration – standardized setups across all Nano applications  
- Infrastructure as code – everything is reproducible and versioned  
- Minimal operational overhead – reduce maintenance burden in production systems  
- Composable architecture – services can be combined or used independently  

## ⚙️ Required Tools
Before continuing, make sure you have the following tools installed and configured.

| Tool                                                                      | Description                                                      |
| ------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **[Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)**   | Azure CLI is a command-line tool for managing Azure resources.   |
| **[Azure VPN Client](https://apps.microsoft.com/detail/9np355qt2sqb)**    | Azure VPN client used to connect to private Azure resources.     |

> ⚠️ If Azure CLI is already installed, make sure it is updated to the latest version: `az upgrade`.
