# Nano.Azure.Account

> _Azure account and environments, including tenant access, subscriptions, and deployment identities_  

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
* **[Dependencies](#dependencies)**  

## Summary
This is the foundation of the Nano Azure infrastructure. It prepares the Azure environment required to host Nano applications, including:

- Azure tenant access
- Subscription setup for environments
- Deployment identity (service principal)
- Secure configuration of CI/CD secrets

This component must be deployed first, as all other **[Nano.Azure](https://github.com/Nano-Core/Nano.Azure/tree/master/README.md#nanoazure)** components depend on it.

> 📖 Learn more about **[Microsoft Azure](https://azure.microsoft.com)**.

## Registration
First, create an **[Azure Account](https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account)** if you do not already have one. Then create a _Pay-As-You-Go_ 
**[Subscription](https://portal.azure.com/#view/Microsoft_Azure_Billing/CatalogBlade/appId/AddSubscriptionButton)** (or another offer) for both Staging and Production directly from 
the Azure portal. This can not be done through the Azure CLI, and must be done in the Azure Protal.

Next, to enable automated deployments, store the tenant id of the Azure account and the subscription ids, as GitHub organization secrets.  

| Secret                              | Description                                     |
| ----------------------------------- | ----------------------------------------------- |
| `AZURE_TENANT_ID`                   | The account identifier of the Azure account.    |
| `STAGING_AZURE_SUBSCRIPTION_ID`     | The identifier of the staging subscription.     |
| `PRODUCTION_AZURE_SUBSCRIPTION_ID`  | The identifier of the production subscription.  |

Open PowerShell and sign in to your Azure account. Select the appropriate subscription (Staging or Production) depending on the environment you are setting up.  

```powershell
az login
``` 

You can also set the subscription using.  

```powershell
az account set -s {{subscription-id}}
```

Last, execute `deploy.ps1` to create the `nano-deploy-service-principal`. This service principal is used for deploying additional resources to the subscriptions. From the output, 
note down the `appId` and `password`, then create the GitHub secrets as shown below.

| Secret                 | Description                                                                |
| ---------------------- | -------------------------------------------------------------------------- |
| `AZURE_CLIENT_ID`      | The app id of the service principal for use with deployments.              |
| `AZURE_CLIENT_SECRET`  | The secret (password) used for authentication for the service-principal.   |

> 💡 If you later need to retrieve information about the created service principal, you can find it in **[Azure App Registrations](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)**.

## Dependencies
The repository has no dependencies and must be the first component created when setting up the Nano infrastructure. All other deployments depend on it.
