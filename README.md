# AVD Alerts Solution
This solution provides a baseline of alerts for AVD that are disabled by default and for ensuring administrators and staff get meaningful and timely alerts when there are problems related to an AVD deployment. The deployment has been tested in Azure Global and Azure US Government and will incorporate storage alerts for either or both Azure Files and/or Azure Netapp Files.

## What's the cost?
While this is highly subjective on the environment, number of triggered alerts, etc. it was designed with cost in mind. The primary resources in this deployment are the Automation Account and Alerts. We recommend you enable alerts in stages and monitor costs, however the overall cost should be minimal.  
- Automation Account runs a script every 5 minutes to collect additional Azure File Share data and averages around $5/month
- Alert Rules vary based on number of times triggered but estimates are under $1/mo each.

## What will be deployed in my subscription?
1. A Resource Group for AVD Metrics
2. An Azure Automation Account with an associated Runbook that writes data to Log Analytics
3. About 15 Common Alerts (disabled) for AVD Hosts and Storage

## Prerequisites
A current AVD deployment and/or Host Pool  
You'll need a Log Analytics Workspace already configured via AVD Insights for monitoring.  

## Alerts Table

Table below shows the Alert Names however the number of alert rules created may be multiple based on different severity and/or additional volume or storage name designators. For example, a deployment with a single Azure Files Storage Account and an Azure NetApp Files Volume would yield 20 alert rules created.

| Name                                                              | Condition (Sev1 / Sev2) |  Signal Type |  Frequency   |  # Alert Rules |
|---                                                                |---                      |---           |---           |---  
| AVD-HostPool-Capacity :one:                                       | 95% / 85%          | Log Analytics  |  5 min       |    2  |
| AVD-HostPool-Disconnected User over XX Hours                      | 24 / 72               | Log Analytics  |  1 hour      |   2  |
| AVD-HostPool-No Resources Available                               | Any are Sev1          | Log Analytics |  15 min      |  2   |
| AVD-Storage-Low Space on ANF Share-XX Percent Remaining-{volumename} :two: | 5 / 15               | Metric Alerts |   1 hour    |  2/vol  |
| AVD-Storage-Low Space on Azure File Share-XX% Remaining :two:     | 5 / 15                | Log Analytics  |   1 hour     |   2   |
| AVD-Storage-Over 200ms Latency for Storage Act-{storacctname}     | na / 200ms            | Metric Alerts |  15 min     |  2/stor acct |
| AVD-Storage-Possible Throttling Due to High IOPs-{storacctname}   | na / custom :three:   | Metric Alerts | 15 min        | 2/stor acct |
| AVD-Storage-Azure Files Availability-{storacctname}               | 99 / na               | Metric Alerts | 5 min         | 2/stor acct |
| AVD-VM-Available Memory Less Than XGB                             | 1 / 2                 | Metric Alerts | 5 min         |   2  |
| AVD-VM-FSLogix Profile Failed (Event Log Indicated Failure)       | Any are Sev1          | Log Analytics | 5 min         |   1  |
| AVD-VM-Health Check Failure                                       | Any are Sev1          | Log Analytics | 5 min         |   1  |
| AVD-VM-High CPU XX Percent                                        | 95 / 85               | Metric Alerts | 5 min         |   2  |
| AVD-VM-Local Disk Free Space X%                                   | 5 / 10                | Log Analytics | 15 min        |   2  |

__NOTE:__  
:one: __Alert based on Runbook for Azure Files and ANF__  
:two: __Alert based on Runbook for AVD Host Pool information__  
:three: __See the following for custom condition: [How to create an alert if a file share is throttled](https://docs.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-performance#how-to-create-an-alert-if-a-file-share-is-throttled)__

[**Log Analytics Query Reference**](AlertQueryReference.md)

## Deploy via Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmain%2Fsolution.json)
[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmain%2Fsolution.json)

## Deploy from PowerShell
Consider using the script to build out your parameters file in the ./scripts folder. This will prompt for information and retrieve the needed resource IDs as well as create a timestamped parameters JSON file.  
[GetParamsInfo.PS1](./scripts/GetParamsInfo.ps1)

You will need the appropriate PowerShell modules installed and connected to Azure.  Then you can run the following from PowerShell:  
```PowerShell
New-AzDeployment -Name "AVD-Alerts-Solution" -TemplateUri https://raw.githubusercontent.com/JCoreMS/AVDAlerts/main/solution.json -TemplateParameterFile <YourParametersFile> -Location <region>
```
