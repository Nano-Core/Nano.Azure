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
First, create an **[Azure account](https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account)** if you do not already have one. Next, create a _Pay-As-You-Go_ 
(or another suitable offer) subscription for each required environment, such as **Staging** and **Production**, as well as any additional environments you may need. This must 
be done directly in the Azure Portal using the **[Create Subscription](https://portal.azure.com/#view/Microsoft_Azure_Billing/CatalogBlade/appId/AddSubscriptionButton)** page.  

> ⚠️ Subscription creation is not supported via Azure CLI and must be completed in the Azure Portal.

Next, to enable automated deployments, store the tenant id of the Azure account and the subscription ids, as GitHub organization secrets.  

| Secret                                    | Type   | Description                                               |
| ----------------------------------------- | ------ |---------------------------------------------------------- |
| `AZURE_TENANT_ID`                         | Secret | The account identifier of the Azure account.              |
| `{{environment}}__AZURE_SUBSCRIPTION_ID`  | Secret | The identifier of the subscription of the environment.    |

Open PowerShell and sign in to your Azure account. Select the appropriate subscription depending on the environment you are setting up.  

```powershell
az login;
``` 

You can also set the subscription using.  

```powershell
az account set -s {{subscription-id}};
```

To verify that you are signed in and connected to the correct subscription, use the following command. It should then show you the tenant and subscription id.  

```powershell
az account show;
```

Last, execute `deploy.ps1` to create the `nano-deploy-service-principal`. This service principal is used for deploying additional resources to the subscriptions. From the output, 
note down the `appId` and `password`.

> ⚠️ Ensure all required variables are specified in the PowerShell script before execution.  

Then create the GitHub secrets as shown below.  

| Secret                 | Type   | Description                                                                |
| ---------------------- | ------ | -------------------------------------------------------------------------- |
| `AZURE_CLIENT_ID`      | Secret | The app id of the service principal for use with deployments.              |
| `AZURE_CLIENT_SECRET`  | Secret | The secret (password) used for authentication for the service-principal.   |

> 💡 If you later need to retrieve information about the created service principal, you can find it in **[Azure App Registrations](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)**.

## Dependencies
The repository has no dependencies and must be the first component created when setting up the Nano infrastructure. All other deployments depend on it.
