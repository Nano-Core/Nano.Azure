# Nano.Azure.SqlServer

> _Azure SQL Server database server for Nano applications._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
* **[Dependencies](#dependencies)**  

## Summary
SQL Server is a relational database management system (RDBMS) developed by Microsoft. It is designed to store, retrieve, and manage data for a wide range of applications, from 
small-scale projects to large enterprise systems. SQL Server supports Structured Query Language (SQL) for querying and managing data and offers advanced features like data 
replication, encryption, and full-text search. It integrates well with other Microsoft products and services, making it a popular choice for businesses using the Microsoft 
ecosystem. SQL Server also includes tools for data analysis, reporting, and integration, making it a comprehensive platform for data management.  
  
Create a SQL Server to host databases used by Nano applications.  

> 📖 Learn more about **[Azure SQL Server](https://learn.microsoft.com/en-us/azure/azure-sql)**.

After successful registration, enable Defender directly on the SQL Server resource in the Azure Portal. This setting is not currently configurable via the Azure CLI.  

## Registration
Coming...

## Dependencies
PostgreSQL has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                            | Description                                                             | 
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | 
| **[Nano.Azure](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Account/README.md#nanoazureaccount)**                   | The is the foundation or prerequites of the Nano Azure infrastructure.  |
| **[Nano.Azure.Monitoring](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Monitoring/README.md#nanoazuremonitoring)**  | Components for centralized monitoring and logging                       |
| **[Nano.Azure.Kubernetes](https://github.com/Nano-Core/Nano.Azure/tree/master/Nano.Azure.Kubernetes/README.md#nanoazurekubernetes)**  | The Azure Kubernetes Service (AKS).                                     |
