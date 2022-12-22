# AVD Alerts Solution

[Home](./README.md) | [PostDeployment](./PostDeploy.md) | [How to Change Thresholds](./ChangeAlertThreshold.md) | [Alert Reference](./AlertReference.md) | [Excel List of Alert Rules](https://github.com/JCoreMS/AVDAlerts/raw/main/references/alerts.xlsx) | [Update History](./UpdateHistory.md)

**Note:**  
Deployments from 12/5/2022 to 12/22/2022 may not have working Logic Apps for AzFiles and Host Pool data. The HTTP action may be missing the webhook URI. Please redeploy or manually create another webhook within the Runbook for each and update the Logic App HTTP action URI.  

## Description

This solution provides a baseline of alerts for AVD that are disabled by default and for ensuring administrators and staff get meaningful and timely alerts when there are problems related to an AVD deployment. The deployment has been tested in Azure Global and Azure US Government and will incorporate storage alerts for either or both Azure Files and/or Azure Netapp Files.

There are 2 different deployments depending on your AVD infrastructure.  

1. **Enterprise** - This is a "Tenant" level deployment for those with AVD resources in multiple subscriptions. (i.e. Log Analytics, VMs, and storage in various other subscriptions)

2. **Subscription** - This is a Subscription wide deployment where all your AVD resources including storage and log analytics workspace are within the same subscription.  

## Prerequisites  

For both solutions the logic app and Runbook created to collect Azure Storage information requires "Allow storage account key access" to be Enabled within the Configuration section of the storage account. (default setting)

**Enterprise**  
An AVD deployment and/or storage or Log Analytics workspaces in multiple subscriptions within the same Azure AD Tenant. Owner Role at the Tenant level which can be defined via [Azure CLI or PowerShell.](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-to-tenant?tabs=azure-cli#required-access)

Once you are Global Admin ensure your Azure AD Tenant is configure to [allow Admins to manage access to all Subscriptions.](https://docs.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin#elevate-access-for-a-global-administrator)

Additionally you will need to run the following as Global Admin does not have the ability to deploy at the tenant scope by default. (The provided deployment PowerShell will add this for you.)

```PowerShell
New-AzRoleAssignment -SignInName "[userId]" -Scope "/" -RoleDefinitionName "Owner"
```
**Subscription**  
An AVD deployment and the Owner Role on the Subscription containing the AVD resources, VMs and Storage.  You must have also pre-configured the AVD Insights as it will enable diagnostic logging for the Host Pools and associated VMs in which the alerts rely on.  

## What's deployed to my Subscription?

Names will be created with a standard 'avdmetrics' in the name and vary based on input for things like site, environment type, etc.

Resource Group starting with the name "rg-avdmetrics-" with the following:  

- Automation Account with a Runbook (for Host Pool Information not otherwise available)  
- Identity for the Automation Account in which the name will start with "aa-avdmetrics-"
- Logic App that execute every 5 minutes (Host Pool Info Runbook)

The Automation Account Identity will be assigned the following roles at the Subscription level:

- Desktop Virtualization Reader
- Reader and Data Access (Storage Specific)

## What's the cost?

While this is highly subjective on the environment, number of triggered alerts, etc. it was designed with cost in mind. The primary resources in this deployment are the Automation Account and Alerts. We recommend you enable alerts in stages and monitor costs, however the overall cost should be minimal.  

- Automation Account runs a script every 5 minutes to collect additional Azure File Share data and averages around $5/month
- Alert Rules vary based on number of times triggered but estimates are under $1/mo each.

## Alerts Table

Table below shows the Alert Names however the number of alert rules created may be multiple based on different severity and/or additional volume or storage name designators. For example, a deployment with a single Azure Files Storage Account and an Azure NetApp Files Volume would yield 20 alert rules created. [(Excel Table)](https://github.com/JCoreMS/AVDAlerts/raw/main/references/alerts.xlsx)

| Name                                                              | Condition (Crit/Warn/Info) |  Signal Type |  Frequency    |  # Alert Rules |
|---                                                                |---                    |---             |---            |---  
| AVD-HostPool-Capacity :one:                                       | 95% / 85% / 50%       | Log Analytics  |  5 min        |  3   |
| AVD-HostPool-Disconnected User over XX Hours                      | 24 / 72               | Log Analytics  |  1 hour       |  2   |
| AVD-HostPool-No Resources Available                               | Any are Sev1          | Log Analytics  |  15 min       |  1   |
| AVD-Storage-Low Space on ANF Share-XX Percent Remaining-{volumename} | 5 / 15             | Metric Alerts  |  1 hour       |  2/vol  |
| AVD-Storage-Low Space on Azure File Share-X% Remaining-{volumename} :one:  | 5 / 15       | Log Analytics  |  1 hour       |  2/share  |
| AVD-Storage-Over XXms Latency for Storage Act-{storacctname}      | 100ms / 50ms          | Metric Alerts  |  15 min       |  2/stor acct |
| AVD-Storage-Over XXms Latency Between Client-Storage-{storacctname}| 100ms / 50ms         | Metric Alerts  |  15 min       |  2/stor acct |
| AVD-Storage-Possible Throttling Due to High IOPs-{storacctname}   | na / custom :two:     | Metric Alerts  |  15 min       |  1/stor acct |
| AVD-Storage-Azure Files Availability-{storacctname}               | 99 / na               | Metric Alerts  |  5 min        |  1/stor acct |
| AVD-VM-Available Memory Less Than XGB                             | 1 / 2                 | Metric Alerts  |  5 min        |   2  |
| AVD-VM-Health Check Failure                                       | Any are Sev1          | Log Analytics  |  15 min       |   1  |
| AVD-VM-High CPU XX Percent                                        | 95 / 85               | Metric Alerts  |  5 min        |   2  |
| AVD-VM-Local Disk Free Space X%                                   | 5 / 10                | Log Analytics  |  15 min       |   2  |
| AVD-VM-FSLogix Profile Failed (Less Than X% Free Space)           | 2 / 5                 | Log Analytics  |  5 min        |   2  |
| AVD-VM-FSLogix Profile Failed due to Network Issue                | na                    | Log Analytics  |  5 min        |   1  |
| AVD-VM-FSLogix Profile-PathNotFound                               | na                    | Log Analytics  |  5 min        |   1  |
| AVD-VM-FSLogix Profile-FailedReAttach                             | na                    | Log Analytics  |  5 min        |   1  |

**NOTES:**  
:one: Alert based on associated Logic App and Runbook  
:two: See the following for custom condition. Note that both Standard and Premium values are incorporated into the alert rule. ['How to create an alert if a file share is throttled'](https://docs.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-performance#how-to-create-an-alert-if-a-file-share-is-throttled)  

[**Alert Reference**](AlertReference.md)

## Deployment / Installation

Use the associated PowerShell script to gather needed information about your environment and deploy the corresponding solution.

### Subscription ONLY based Deployment

This is used for deployment at the Subscription level with all resources related to AVD inside a SINGLE subscription to include the Log Analytics workspace, VMs and AVD specific resources. You will need the appropriate Azure PowerShell modules installed and the Contributor role at the Subscription level.  
[DeployToSub.PS1](./deploySubscription/scripts/DeployToSub.ps1)

### Tenant Level (Enterprise) based Deployment

This is used for deployment at the Tenant level with resources related to AVD spread across MULTIPLE subscriptions.  You will need the appropriate Azure PowerShell modules installed and the deployment ability at the Tenant level. Global Admins do not have deployment privileges at the Tenant level by default, thus the script includes adding the below role assignment for deployment.  
[DeployToTenant.PS1](./deployEnterprise/scripts/DeployToTenant.ps1)

**Note:** The above deployment script for the Tenant will add your account to the Tenant Level as an Owner. You can also accomplish this manually by running one of the following. (Within Cloud Shell is ideal and the fastest)  
Reference: [Tenant deployments with ARM templates](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-to-tenant?tabs=azure-cli)

```azurepowershell-interactive
New-AzRoleAssignment -SignInName "[userId]" -Scope "/" -RoleDefinitionName "Owner"
```
```azurecli-interactive
az role assignment create --assignee "[userId]" --scope "/" --role "Owner"
```


### [PostDeployment](./PostDeploy.md)

See the above linked section for information on how to enable and view the alerts created.
