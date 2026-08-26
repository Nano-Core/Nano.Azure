# Nano.Azure.GitHubRunner

> _Azure Container Apps Job for GitHub self-hosted runners._

***

## Table of Contents
* **[Summary](#summary)**  
* **[Registration](#registration)**  
  * **[GitHub Runner Image](#github-runner-image)**  
  * **[GitHub App Authentication](#github-app-authentication)**  
  * **[Polling Interval](#polling-interval)**  
  * **[Environment Filter](#environment-filter)**  
  * **[KEDA Scaling](#keda-scaling)**  
* **[Dependencies](#dependencies)**  

## Summary
This component deploys and manages a GitHub self-hosted runner as an Azure Container Apps Job. It automatically provisions the job if it does not exist, or updates it if it already 
exists, ensuring the runner configuration stays in sync with the desired state.

The job is configured to authenticate using a GitHub App and scales dynamically based on queued GitHub Actions workloads.

## Registration
This deployment provisions a GitHub self-hosted runner job in Azure Container Apps.

### GitHub Runner Image
The runner uses a custom container image maintained by Nano-Core. It is based on a widely used community GitHub Actions runner image, extended with the required tools, dependencies,
and configurations needed for Nano workloads and components.

> 📖 Learn more about **[Nano GitHub Runner Image](https://github.com/Nano-Core/.githubRunnerImage)**

### GitHub App Authentication
Authentication is handled through a GitHub App, which provides secure, scoped access to the GitHub API without using personal tokens.

This is required for registering, claiming, and managing self-hosted runners.

See **[Nano.GitHub.App](https://github.com/Nano-Core/Nano.GitHub/blob/master/Nano.GitHub.RunnerApp/README.md#nanogithubrunnerapp)**.

### Polling Interval
The runner polls GitHub every 30 seconds, which is the minimum supported interval in Azure Container Apps.  

This means there may be a short delay before newly queued workflows are picked up.

### Environment Filter
Each environment is isolated using GitHub runner labels to ensure workloads are routed correctly across environments (e.g. Staging vs Production).

When using the runner, ensure the correct labels are included in `runs-on` so jobs are scheduled to the intended environment:

```yaml
runs-on:
  - self-hosted
  - linux
  - ${{ github.ref == 'refs/heads/master' && 'Production' || 'Staging' }}
```

### KEDA Scaling
Scaling is driven by a KEDA-based GitHub Runner scaler that monitors the GitHub API for queued workflow jobs.

When jobs are detected, Azure Container Apps automatically increases the number of job executions; when the queue is empty, it scales back down. This ensures efficient, event-driven 
scaling without requiring webhooks or manual intervention.

When no runners are active, compute resources scale to zero, resulting in no running cost.  

## Dependencies
GitHub Runner has the following dependencies that must be deployed or otherwise satisfied prior to setup.  

| Dependency                                                                                                                             | Description                                                                                  | 
| -------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | 
| **[Nano.GitHub.App](https://github.com/Nano-Core/Nano.GitHub/blob/master/Nano.GitHub.RunnerApp/README.md#nanogithubrunnerapp)**        | GitHub App used for the Container App job to authenticate when polling for workflows jobs.   |
| **[Nano.Azure.Delivery](https://github.com/Nano-Core/Nano.Azure/blob/master/Nano.Azure.Delivery/README.md#nanoazuredelivery)**         | The Azure Kubernetes Delivery components.                                                    |
