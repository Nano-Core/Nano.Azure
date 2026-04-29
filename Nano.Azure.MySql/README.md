# Nano.Azure.Sql.MySql

> _Azure flexible MySQL database server for Nano applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
* **[Dependencies](#dependencies)**  

## Summary
MySQL is an open-source relational database management system (RDBMS) known for its speed, reliability, and ease of use. Developed by Oracle, it is one of the most popular databases 
for web applications and is a key component of the LAMP stack (Linux, Apache, MySQL, PHP/Perl/Python). MySQL supports SQL for managing and querying data and offers features like 
replication, partitioning, and full-text search. It is highly scalable, making it suitable for both small-scale projects and large, high-traffic websites. MySQL’s strong community 
support and wide range of tools make it a preferred choice for developers and businesses around the world.  

> 📖 Learn more about **[Azure MySql](https://learn.microsoft.com/azure/mysql)**.

## Registration
Execute the `deploy.ps1` to create a flexible MySQL database server on Azure.  

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

The default SKU is set to: **`Standard_D2ads_v5`**, but other SKUs can also be used depending on workload requirements.  
Azure virtual machine SKUs follow this general format: `[Family][Size][Features][Generation]`

The virtual machine familiy types is listed below.  

| Family | Meaning            | Typical use                       |
| ------ | ------------------ | --------------------------------- |
| B      | Burstable          | Dev, low-cost, light workloads    |
| D      | General purpose    | Most apps, balanced CPU/memory    |
| E      | Memory optimized   | Databases, in-memory workloads    |
| F      | Compute optimized  | High CPU workloads                |

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

> ⚠️ Be ware that the chosen tier must match the chosen SKU. e.g. Family=B, Tier=Burstable.

To see all available SKUs for a specific region use the command below.  

```powershell
az mysql flexible-server list-skus -l $env:AZURE_LOCATION -o table;
```

You can also check out the official list of available SKUs on the **[MySQL Service Tiers](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-service-tiers-storage)** page.

Optionally, you can enable high availability for the MySQL server. In Azure Database for MySQL Flexible Server, high availability provides automatic failover between zones to 
improve resilience and reduce downtime in case of infrastructure or zone-level failures. To enable it, simply uncomment the `--high-availability`, `--zone`, and `--standby-zone` 
parameters in the `deploy.ps1` script’s create command.  

Database backups have also been configured to run every 24 hours, with a maximum retention period of 35 days. To enable geo-redundant backups, uncomment the `--geo-redundant-backup` 
parameter in the create command.  

> ⚠️ MySQL database backups is not integrated with **[Nano.Azure.Backup](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Backup/README.md#nanoazurebackup)**, 
but has its own integrated configurable service.  

Next, create the required secrets in GitHub for the MySQL server. These secrets will be used later to securely connect your applications to the database.  

| Secret                                    | Type      | Description                                                                    |
| ----------------------------------------- | --------- | ------------------------------------------------------------------------------ |
| `MYSQL_PORT`                              | Variable  | The MySQL port. The is a cross environment variable.                           |
| `{{environment}}_MYSQL_HOST`              | Secret    | The MySQL host.                                                                |
| `{{environment}}_MYSQL_ADMIN_USER `       | Secret    | The MySQL admin username, used when applying EF migrations during deployment.  |
| `{{environment}}_MYSQL_ADMIN_PASSWORD `   | Secret    | The MySQL admin password, used when applying EF migrations during deployment.  |

The MySQL connection string has this format.  

```
Server={server};Port={{port}};Database={database};Uid={username};Pwd={password};SslMode=Preferred;  
```

The Azure maintainance window is set to sunday at 04:00.

The default transaction isolation level can optionally be changed to `READ-UNCOMMITTED` for improved performance. However, this should be used with caution, as it may lead to dirty 
reads and less consistent query results in some applications.  

The diagnostic settings for MySQL includes both `AllMetrics` for metrics, and `MySqlSlowLogs` and `MySqlAuditLogs`, and the time-grain is set tot 1-minute aggregation interval. This 
value can be adjusted if needed. You can retrieve the full list of supported metric categories for the MySQL resource using the following command.  

```powershell
az monitor diagnostic-settings categories list --resource $env:MYSQL_ID;
```

Last, a couple of default alerts have been configured for the MySQL server and are associated with the action group created in 
**[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**. These alerts monitor High CPU Usage, 
High Memory Usage, High Number Of Connections, High Storage IO, and High Storage Percent.

## Dependencies
MySQL has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Account/README.md#nanoazureaccount)**                   | The is the foundation or prerequites of the Nano Azure infrastructure.  |
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging                       |
