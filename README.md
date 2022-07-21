# AVD Alerts Solution
This solution provides a baseline of alerts for AVD that are disabled by default and for ensuring administrators and staff get meaningful and timely alerts when there are problems related to an AVD deployment. The deployment has been tested in Azure Global and Azure US Government and will incorporate storage alerts for either or both Azure Files and/or Azure Netapp Files.

## What's the cost?
While this is highly subjective on the environment, number of triggered alerts, etc. it was designed with cost in mind. The primary resources in this deployment are the Automation Account and Alerts. We recommend you enable alerts in stages and monitor costs, however the overall cost should be minimal.  
- Automation Account runs a script every 5 minutes to collect additional Azure File Share data and averages around $2/month
- Alert Rules vary based on number of times triggered but estimates are under $1/mo each. (There are approximately 15 you can enable)

## What will be deployed in my subscription?
1. A Resource Group for AVD Metrics
2. An Azure Automation Account with an associated Runbook that writes data to Log Analytics
3. About 15 Common Alerts (disabled) for AVD Hosts and Storage

## Prerequisites
A current AVD deployment and/or Host Pool  
You'll need a Log Analytics Workspace already configured via AVD Insights for monitoring.  

## Alerts Table

| Name                                                              | Condition (Sev1 / Sev2) |  Signal Type |  Frequency   |  
|---                                                                |---                      |---           |---           |  
| AVD-HostPool-Capacity                                             | At 95% / 85%          | Log Analytics  |  5 min       |
| AVD-HostPool-Disconnected User over XX Hours                      | 24 / 72               | Log Analytics  |  1 hour      |
| AVD-HostPool-No Resources Available                               | Any are Sev1          | Log Analytics |  15 min      |
| AVD-Storage-Low Space on ANF Share-XX Percent Remaining-{volumename}| 5 / 15               | Metric Alerts |   1 hour      |
| AVD-Storage-Low Space on Azure File Share-XX% Remaining           | 5 / 15                | Log Analytics  |   1 hour     |
| AVD-Storage-Over 200ms Latency for Storage Act-{storacctname}     | na / 200ms            | Metrice Alerts |  15 min     |
| AVD-Storage-Possible Throttling Due to High IOPs-{storacctname}   | na / custom          | Metric Alerts | 15 min        |
| AVD-VM-Available Memory Less Than XGB                             | 1 / 2                 | Metric Alerts | 5 min         |
| AVD-VM-FSLogix Profile Failed (Event Log Indicated Failure)       | Any are Sev1          | Log Analytics | 5 min         |
| AVD-VM-Health Check Failure                                       | Any are Sev1          | Log Analytics | 5 min         |
| AVD-VM-High CPU XX Percent                                        | 95 / 85               | Metric Alerts | 5 min         |
| AVD-VM-Local Disk Free Space X%                                   | 5 / 10                | Log Analytics | 15 min        |

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
