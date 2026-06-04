# Nano.Azure.Postgres

> _Azure PostgreSQL database server for Nano applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
* **[Dependencies](#dependencies)**  

## Summary
PostgreSQL, commonly known as Postgres, is an open-source relational database management system (RDBMS) known for its robustness and advanced features. It supports SQL for querying 
and managing data but also extends SQL with powerful features like support for JSON, XML, and custom data types, making it suitable for complex applications. Postgres is highly 
extensible, allowing users to add custom functions, data types, and operators. It also offers strong ACID compliance, ensuring reliable transactions, and supports advanced indexing, 
full-text search, and replication. Due to its flexibility, scalability, and active community support, PostgreSQL is widely used in various industries, from startups to large 
enterprises.  

Create a PostgreSQL Flexible Server to host databases used by Nano applications.  

> 📖 Learn more about **[Azure PostgreSQL](https://learn.microsoft.com/en-us/azure/postgresql/overview)**.

After successful registration, enable Defender directly on the PostgreSQL resource in the Azure Portal. This setting is not currently configurable via the Azure CLI.  

## Registration
Coming...

## Dependencies
PostgreSQL has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging                       |
| **[Nano.Azure.Backup](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Backup/README.md#nanoazurebackup)**              | Backup and recovery services.                                           |
| **[Nano.Azure.Kubernetes](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Kubernetes/README.md#nanoazurekubernetes)**  | The Azure Kubernetes Service (AKS).                                     |
