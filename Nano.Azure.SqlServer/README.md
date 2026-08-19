# Nano.Azure.SqlServer

> _Azure SQL Server for Nano applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[SQL Server](#sql-server)**  
  * **[Database Creation](#database-creation)**
  * **[Network Rules](#network-rules)**  
  * **[Microsoft Defender](#microsoft-defender)**  
* **[Dependencies](#dependencies)**  

## Summary
Microsoft SQL Server is a relational database management system (RDBMS) known for its enterprise-grade reliability, tooling, and deep integration with the .NET ecosystem. It supports 
SQL for querying and managing data, and offers features like columnstore indexes, in-memory OLTP, and built-in high availability. SQL Server is widely used for line-of-business 
applications, data warehousing, and enterprise workloads where strong tooling, T-SQL feature depth, and Microsoft ecosystem integration are priorities.  

Azure SQL Database is made up of two separate resources: a logical **server**, which handles authentication and networking, and one or more **databases** underneath it, which hold 
the actual compute, storage, and billing configuration. This repository only provisions the server. Databases are created individually by each application, as described in 
**[Database Creation](#database-creation)** below.  

Create a SQL Server to host databases used by Nano applications.  

> 📖 Learn more about **[Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database)**.

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

Add the following GitHub organization variables.  

| Secret                           | Type    | Description                                     |
| -------------------------------- | ------- |------------------------------------------------ |
| `AZURE_RESOURCE_GROUP_DATABASE`  | vars    | The Azure resource group of the SQL Database.   |

### SQL Server
Execute the next part of the `deploy.ps1` to create a logical SQL Server on Azure.  

The SQL Server resource itself has no SKU, storage, or tier. It is only an authentication and networking wrapper. Compute, storage, and scaling are all configured per-database, at 
the point each application creates its own database. See **[Database Creation](#database-creation)** below.

> ⚠️ Make sure to store the information returned during creation. The _admin password_ for instance cannot be retrieved later.  

Create the required secrets in GitHub for the SQL Server. They will be used later to securely connect your applications to the database.  

| Secret                                  | Type     | Description                                                                    |
| --------------------------------------- | -------- | ------------------------------------------------------------------------------ |
| `{{environment}}_SQL_ADMIN_PASSWORD`    | Secret   | The SQL Server admin password, used when applying EF migrations during deployment.  |

The SQL Server connection string has this format.  

```
Server={server};Database={database};User Id={username};Password={password};Encrypt=True;  
```

### Database Creation
Databases are not created as part of this deploy script.  

Each application creates and owns its own database, as a dedicated step in its own CI/CD pipeline, against the shared server provisioned here. This includes the database's SKU, storage, 
backup retention, high availability, maintenance, diagnostics settings, and alerts — all configured as part of that pipeline step.  

Transaction isolation defaults to `read committed snapshot` (RCSI), Azure SQL Database's own default, and is not explicitly configured as part of this.

### Network Rules
The SQL Server has no public access by default. 

A Private Endpoint is created for the Kubernetes virtual network, enabling applications running in Kubernetes to securely access the SQL Server over a private connection.

To get the available `group-id`, run the following command.  

```powershell
az network private-link-resource list --id $env:SQLSERVER_ID;
```

> ⚠️ The private endpoint must be deployed in the same Azure region as the virtual network (VNet) it is associated with.

Optionally, IP address whitelisting can be configured to allow access to the SQL Server. By default, access is fully restricted, and no external connections are permitted. The 
Nano system does not depend on IP whitelisting for connectivity, and using it is generally discouraged as it can negatively impact the overall cloud security score. If IP 
whitelisting is required, it can be configured using the following command.  

```powershell
$env:NETWORK_RULE_NAME = "";
$env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS_START = "0.0.0.0";
$env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS_END = "255.255.255.255";

az sql server firewall-rule create `
    -n $env:NETWORK_RULE_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    -s $env:APP_NAME `
    --start-ip-address $env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS_START `
    --end-ip-address $env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS_END;
```

> ⚠️ Whitelisting IP addresses can reduce the overall security posture and negatively impact the security score.  

### Microsoft Defender
After successful registration, enable Defender directly on the SQL Server resource in the Azure Portal. 

> ⚠️ This setting is not currently configurable via the Azure CLI.  

## Dependencies
SQL Server has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging                       |
| **[Nano.Azure.Kubernetes](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Kubernetes/README.md#nanoazurekubernetes)**  | The Azure Kubernetes Service (AKS).                                     |
