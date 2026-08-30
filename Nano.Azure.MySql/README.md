# Nano.Azure.MySql

> _Azure flexible MySQL database server for Nano applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[MySQL Flexble Server](#mysql-flexble-server)**  
  * **[Database Backup](#database-backup)**
  * **[Storage Auto Growth](#storage-auto-growth)**
  * **[IOPS Auto Scaling](#iops-auto-scaling)**
  * **[High Availability](#high-availability)**
  * **[Managed Idenity](#managed-idenity)**  
  * **[Maintenance](#maintenance)**  
  * **[Transaction Isolation Level](#transaction-isolation-level)**  
  * **[Alerts](#alerts)**  
  * **[Diagnostics Settings](#diagnostics-settings)**  
  * **[Network Rules](#network-rules)**  
  * **[Microsoft Defender](#microsoft-defender)**  
* **[Dependencies](#dependencies)**  

## Summary
MySQL is an open-source relational database management system (RDBMS) known for its speed, reliability, and ease of use. Developed by Oracle, it is one of the most popular databases 
for web applications and is a key component of the LAMP stack (Linux, Apache, MySQL, PHP/Perl/Python). MySQL supports SQL for managing and querying data and offers features like 
replication, partitioning, and full-text search. It is highly scalable, making it suitable for both small-scale projects and large, high-traffic websites. MySQL’s strong community 
support and wide range of tools make it a preferred choice for developers and businesses around the world.  

Create a MySQL Flexible Server to host databases used by Nano applications.  

#### Azure MySQL Architecture
![Nano Azure MySQL Architecture](https://raw.githubusercontent.com/Nano-Core/Nano.Azure/master/.assets/Nano-Database-MySql.jpg)

> 📖 Learn more about **[Azure MySql](https://learn.microsoft.com/azure/mysql)**.

## Registration
Start by registering the required Azure providers and creating the resource group, by executing the top part of the `deploy.ps1`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

Add the following GitHub organization variables.  

| Secret                           | Type    | Description                                     |
| -------------------------------- | ------- |------------------------------------------------ |
| `AZURE_RESOURCE_GROUP_DATABASE`  | vars    | The Azure resource group of the SQL Database.   |

### MySQL Flexble Server
Execute the next part of the `deploy.ps1` to create a managed flexible MySQL database server on Azure.  

The default SKU is set to: `Standard_D2ads_v5`, but other SKUs can also be used depending on workload requirements and the availability in Azure regions.  

Azure virtual machine SKUs follow this general format: `[Family][Size][Features][Generation]`.  

The virtual machine familiy types is listed below.  

| Family | Meaning            | Typical use                                                                                             |
| ------ | ------------------ | ------------------------------------------------------------------------------------------------------- |
| B      | Burstable          | Dev, low-cost, light workloads. ⚠️ Be aware that you cannot later upgrade to a different family type.   |
| D      | General Purpose    | Most apps, balanced CPU/memory                                                                          |
| E      | Memory Optimized   | Databases, in-memory workloads                                                                          |
| F      | Compute Optimized  | High CPU workloads                                                                                      |

And the SKU feature letters.  

| Letter | Meaning                                            |
| ------ | -------------------------------------------------- |
| a      | AMD CPU                                            |
| i      | Intel CPU                                          |
| d      | Local temporary SSD                                |
| s      | Premium SSD support                                |
| e      | Extra memory (memory optimized variants)           |
| z      | High memory / special variants                     |
| l      | Low latency / local disk optimized (older series)  |

> ⚠️ Be aware that the chosen tier must match the chosen SKU. e.g. Family=B, Tier=Burstable.

To see all available SKUs for a specific region use the command below.  

```powershell
az mysql flexible-server list-skus -l $env:AZURE_LOCATION -o table;
```

You can also check out the official list of available SKUs on the **[MySQL Service Tiers](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-service-tiers-storage)** page.

> ⚠️ Make sure to store the information returned during creation. The _admin password_ for instance cannot be retrieved later.  

Create the required secrets in GitHub for the MySQL server. They will be used later to securely connect your applications to the database.  

| Secret                                  | Type     | Description                                                                    |
| --------------------------------------- | -------- | ------------------------------------------------------------------------------ |
| `{{environment}}_SQL_ADMIN_PASSWORD`    | Secret   | The MySQL admin password, used when applying EF migrations during deployment.  |

The MySQL connection string has this format.  

```
Server={server};Port={{port}};Database={database};Uid={username};Pwd={password};SslMode=Preferred;  
```

### Database Backup
Database backups have also been configured to run every 24 hours, with a maximum retention period of 35 days.  

> ⚠️ MySQL database backups is not integrated with **[Nano.Azure.Backup](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Backup/README.md#nanoazurebackup)**, 
but has its own integrated configurable service.  

Also, note that geo-redundant backups are not supported in all regions. If geo-redundant backup is not required, remove the `--geo-redundant-backup Enabled` parameter. Otherwise, ensure that 
the selected region supports geo-redundant backups before deployment.

For a list of supported regions, see: **[Supported Regions](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/overview#azure-regions)**.

### Storage Auto Growth
Storage is set to auto-grow, allowing a flexible scaled database server as data grows. 

### IOPS Auto Scaling
Furthermoe, IOPS is set to auto-grow, allowing flexible a scaled database server.  

### High Availability
High availability is enabled by default for the MySQL server. In Azure Database for MySQL Flexible Server, high availability provides automatic failover between zones to 
improve resilience and reduce downtime in case of infrastructure or zone-level failures.  

To disable high availability, simply comment out the `--high-availability`, `--zone`, and `--standby-zone` parameters in the `deploy.ps1` script’s create command.

### Managed Identity
Both native MySQL password authentication and Microsoft Entra ID authentication are enabled for this server (dual auth). Entra ID is used for all Entra-capable identities via short-lived 
tokens instead of shared secrets. Native auth stays enabled only because the self-hosted Grafana Helm chart has no Entra support for its own database connection, so it uses a dedicated, 
least-privilege SQL user instead.

> 💡 The `aad_auth_only` parameter can be switched to `ON` via the `az mysql flexible-server parameter set` command if no username/password integrations are needed for this server.

> ⚠️ Executing the script requires Groups Administrator, and either Privileged Role Administrator or Global Administrator, in Microsoft Entra ID.

A dedicated user-assigned managed identity is created and attached to the MySQL Flexible Server. The server uses this identity to query Microsoft Graph and validate Entra ID logins (users, groups, 
and service principals). It's not itself used to log in.

Two Entra ID groups control access to the database:

| Group           | Purpose                                                                                         |
| --------------- | ----------------------------------------------------------------------------------------------- |
| `-admins`       | Full admin access (DDL — create / alter / drop).                                                |
| `-developers`   | Read/write access (DML only — select / insert / update / delete), no schema change permissions. |

The `nano-deploy-service-principal` service principal is added to the `-admins` group, granting it full admin access across all databases on this server so CI/CD can run migrations.

To grant access, add the relevant user or identity to the appropriate group in Entra ID. No changes to the database or this script are needed.

Before acquiring an access token, confirm the membership is visible by running the following command. If this returns `false`, wait a few minutes and check again.

```powershell
az ad group member check --group $env:ADMIN_GROUP_NAME --member-id $env:USER_OBJECT_ID --query value -o tsv;
```

> ⚠️ Entra ID/Graph changes can take a few minutes to propagate.

When running `az account get-access-token`, if the token doesn't reflect a recent group change, even after propagation completes, re-authenticate with `az account clear && az login` to get 
a fresh one.

> ⚠️ Access tokens are cached locally by the Azure CLI.

### Maintenance
The Azure maintainance window is set to sunday at 04:00.

### Transaction Isolation Level
The default transaction isolation level can optionally be changed to `READ-UNCOMMITTED` for improved performance. However, this should be used with caution, as it may lead to dirty 
reads and less consistent query results in some applications.  

### Alerts
Last, a couple of default alerts have been configured for the MySQL server and are associated with the action group created in 
**[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**. These alerts monitor High CPU Usage, 
High Memory Usage, High Number Of Connections, High Storage IO, and High Storage Percent.

### Diagnostics Settings
The diagnostic settings for MySQL includes both `AllMetrics` for metrics, and `MySqlSlowLogs` and `MySqlAuditLogs`, and the time-grain is set tot 1-minute aggregation interval. This 
value can be adjusted if needed. You can retrieve the full list of supported metric and log categories for the MySQL resource using the following command.  

```powershell
az monitor diagnostic-settings categories list --resource $env:MYSQL_ID;
```

### Network Rules
The MySQL flexible server has no public access by default. 

A Private Endpoint is created for the Kubernetes virtual network, enabling applications running in Kubernetes to securely access the MySQL server over a private connection.

To get the available `group-id`, run the following command.  

```powershell
az network private-link-resource list --id $env:MYSQL_ID;
```

> ⚠️ The private endpoint must be deployed in the same Azure region as the virtual network (VNet) it is associated with.

Optionally, IP address whitelisting can be configured to allow access to the MySQL server. By default, access is fully restricted, and no external connections are permitted. The 
Nano system does not depend on IP whitelisting for connectivity, and using it is generally discouraged as it can negatively impact the overall cloud security score. If IP 
whitelisting is required, it can be configured using the following command.  

```powershell
$env:NETWORK_RULE_NAME = "";
$env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS_START = "0.0.0.0";
$env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS_END = "255.255.255.255";

az mysql flexible-server firewall-rule create `
    -n $env:APP_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --rule-name $env:NETWORK_RULE_NAME `
    --start-ip-address $env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS_START `
    --end-ip-address $env:NETWORK_RULE_WHITE_LISTED_IP_ADDRESS_END;
```

> ⚠️ Whitelisting IP addresses can reduce the overall security posture and negatively impact the security score.  

### Microsoft Defender
After successful registration, enable Defender directly on the MySQL resource in the Azure Portal. 

> ⚠️ This setting is not currently configurable via the Azure CLI.  

## Dependencies
MySQL has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging                       |
| **[Nano.Azure.Kubernetes](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Kubernetes/README.md#nanoazurekubernetes)**  | The Azure Kubernetes Service (AKS).                                           |
