# AVD Alerts Solution

[Home](./README.md) | [PostDeployment](./PostDeploy.md) | [How to Change Thresholds](./ChangeAlertThreshold.md) | [Alert Query Reference](./AlertQueryReference.md) | [Excel List of Alert Rules](https://github.com/JCoreMS/AVDAlerts/raw/main/references/alerts.xlsx)

## Description

This solution provides a baseline of alerts for AVD that are disabled by default and for ensuring administrators and staff get meaningful and timely alerts when there are problems related to an AVD deployment. The deployment has been tested in Azure Global and Azure US Government and will incorporate storage alerts for either or both Azure Files and/or Azure Netapp Files.

There are 2 different deployments depending on your AVD infrastructure.  

1. **Enterprise** - This is a "Tenant" level deployment for those with AVD resources in multiple subscriptions. (i.e. Log Analytics, VMs, and storage in various other subscriptions)

2. **Subscription** - This is a Subscription wide deployment where all your AVD resources including storage and log analytics workspace are within the same subscription.  

## Prerequisites  

**NOTE**  
Currently it is required to input ANF and Azure storage resource IDs. This will be addressed at a later time. To ensure deployment simply add an example resource ID in either that you do not currently have resources to ensure deployment of remaining resources.

**Enterprise**  
An AVD deployment and/or storage or Log Analytics workspaces in multiple subscriptions within the same Azure AD Tenant. Owner Role at the Tenant level which can be defined via [Azure CLI or PowerShell.](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-to-tenant?tabs=azure-cli#required-access)

**Subscription**  
An AVD deployment and the Owner Role on the Subscription containing the AVD resources, VMs and Storage.  You must have also pre-configured the AVD Insights as it will enable diagnostic logging for the Host Pools and associated VMs in which the alerts rely on.  

## What's deployed to my Subscription?

Names will be created with a standard 'avdmetrics' in the name and vary based on input for things like site, environment type, etc.

Resource Group starting with the name "rg-avdmetrics-" with the following:  

- Automation Account with 2 Runbooks (1 each for Host Pool and Storage Information not otherwise available)  
- Identity for the Automation Account in which the name will start with "aa-avdmetrics-"
- 2 Logic Apps that execute every 5 minutes (1 for each Runbook)

The Automation Account Identity will be assigned the following roles at the Subscription level:

- Desktop Virtualization Reader
- Reader and Data Access (Storage Specific)

## What's the cost?

While this is highly subjective on the environment, number of triggered alerts, etc. it was designed with cost in mind. The primary resources in this deployment are the Automation Account and Alerts. We recommend you enable alerts in stages and monitor costs, however the overall cost should be minimal.  

- Automation Account runs a script every 5 minutes to collect additional Azure File Share data and averages around $5/month
- Alert Rules vary based on number of times triggered but estimates are under $1/mo each.

## Alerts Table

Table below shows the Alert Names however the number of alert rules created may be multiple based on different severity and/or additional volume or storage name designators. For example, a deployment with a single Azure Files Storage Account and an Azure NetApp Files Volume would yield 20 alert rules created. [(Excel Table)](https://github.com/JCoreMS/AVDAlerts/raw/main/references/alerts.xlsx)

| Name                                                              | Condition (Sev1 / Sev2) |  Signal Type |  Frequency   |  # Alert Rules |
|---                                                                |---                      |---           |---           |---  
| AVD-HostPool-Capacity :one:                                       | 95% / 85%          | Log Analytics  |  5 min       |    2  |
| AVD-HostPool-Disconnected User over XX Hours                      | 24 / 72               | Log Analytics  |  1 hour      |   2  |
| AVD-HostPool-No Resources Available                               | Any are Sev1          | Log Analytics |  15 min      |  1   |
| AVD-Storage-Low Space on ANF Share-XX Percent Remaining-{volumename} :two: | 5 / 15               | Metric Alerts |   1 hour    |  2/vol  |
| AVD-Storage-Low Space on Azure File Share-XX% Remaining :two:     | 5 / 15                | Log Analytics  |   1 hour     |   2   |
| AVD-Storage-Over 200ms Latency for Storage Act-{storacctname}     | na / 200ms            | Metric Alerts |  15 min     |  1/stor acct |
| AVD-Storage-Possible Throttling Due to High IOPs-{storacctname}   | na / custom :three:   | Metric Alerts | 15 min        | 1/stor acct |
| AVD-Storage-Azure Files Availability-{storacctname}               | 99 / na               | Metric Alerts | 5 min         | 1/stor acct |
| AVD-VM-Available Memory Less Than XGB                             | 1 / 2                 | Metric Alerts | 5 min         |   2  |
| AVD-VM-FSLogix Profile Failed (Event Log Indicated Failure)       | Any are Sev1          | Log Analytics | 5 min         |   1  |
| AVD-VM-Health Check Failure                                       | Any are Sev1          | Log Analytics | 5 min         |   1  |
| AVD-VM-High CPU XX Percent                                        | 95 / 85               | Metric Alerts | 5 min         |   2  |
| AVD-VM-Local Disk Free Space X%                                   | 5 / 10                | Log Analytics | 15 min        |   2  |

**NOTES:**  
:one: Alert based on Runbook for Azure Files and ANF  
:two: Alert based on Runbook for AVD Host Pool information  
:three: See the following for custom condition. Note that both Standard and Premium values are incorporated into the alert rule. ['How to create an alert if a file share is throttled'](https://docs.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-performance#how-to-create-an-alert-if-a-file-share-is-throttled)  

[**Log Analytics Query Reference**](AlertQueryReference.md)

## Deploy via Portal

### Subscription ONLY based Deployment

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmain%2FdeploySubscription%2Fsolution.json)
[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmain%2FdeploySubscripiton%2Fsolution.json)

#### Deploy from PowerShell
Consider using the script to build out your parameters file in the ./scripts folder. This will prompt for information and retrieve the needed resource IDs as well as create a timestamped parameters JSON file.  
[GetParamsInfo.PS1](./scripts/GetParamsInfo.ps1)

You will need the appropriate PowerShell modules installed and connected to Azure.  Ensure you also download and configure the provided Parameters file. After which you can then you can run the following from PowerShell: 

```PowerShell
New-AzDeployment -Name "AVD-Alerts-Solution" -TemplateUri https://raw.githubusercontent.com/JCoreMS/AVDAlerts/main/solution.json -TemplateParameterFile <YourParametersFile> -Location <region>
```

### Tenant Level (Enterprise) based Deployment

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmain%2FdeployEnterprise%2Ftenant.solution.json)
[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmain%2FdeployEnterprise%2Ftenant.solution.json)

You will need the appropriate PowerShell modules installed and connected to Azure. Ensure you also download and configure the provided Parameters file. After which you can then you can run the following from PowerShell:  

```PowerShell
New-AzTenantDeployment -Name "AVD-Alerts-Solution" -TemplateUri https://raw.githubusercontent.com/JCoreMS/AVDAlerts/main/deployEnterprise/tenant.solution.json -TemplateParameterFile tenant.solution.parameters.json -Location <region>
```

**See [PostDeployment](./PostDeploy.md) for next steps to enable and view alerts.**
