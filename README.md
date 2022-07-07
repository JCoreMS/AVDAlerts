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

| Name                                                              | Condition                              | Severity  |  Signal Type |  Frequency  |  
|---                                                                |---                                     |---        |---          |---           |  
|  AVD-HostPool-No Resources Available                              | Host Pool has NO available hosts  | 1             | Log Analytics Query  |  15 Minutes  |  
|  AVD-Storage-Low Space on ANF Share-15 Percent Remaining-profiles | VolumeConsumedSizePercentage >= 85  | 2               |Metric Alerts  |  Hourly |  
|  AVD-Storage-Low Space on ANF Share-5 Percent Remaining-profiles  | VolumeConsumedSizePercentage >= 95  | 1               | Metric Alerts  |  Hourly |  
|  AVD-Storage-Low Space on Azure File Share-15 Percent Remaining   | 15% remaining (Value in Runbook output)  | 2          | Log Analytics Query  |  10 Minutes |  
|  AVD-Storage-Low Space on Azure File Share-5 Percent Remaining   | 5% remaining (Value in Runbook output)  | 1            | Log Analytics Query  |  10 Minutes |  
|  AVD-Storage-Over 200ms Latency for Storage Acct-'storageacctname'   | SuccessServerLatency > 200  | 2          |  Metric Alerts  |  15 Minutes  |  
|  AVD-Storage-Possible Throttling Due to High IOPs-'storageacctname'   | Transactions >= 1 (description has details)  | 2          | Metric Alerts  | 5 Minutes |  
|  AVD-VM-Available Memory Less Than 1GB   | Available Memory Bytes <= 1073741824  | 1          | Metric Alerts  |  5 Minutes |  
|  AVD-VM-Available Memory Less Than 2GB   | Available Memory Bytes <= 2147483648  | 2          | Metric Alerts  |  5 Minutes |  
|  AVD-VM-FSLogix Profile Failed (Event Log Indicated Failure) | Table rows >=1 In selected dimensions | 1  |  Log Analytics Query  |  5 Minutes |  
|  AVD-VM-Health Check Failure  | Table rows >=1 In selected dimensions (at least one AVD Health check failed) | 1  | Log Analytics Query |  5 Minutes |  
|  AVD-VM-High CPU 85 Percent  | Percentage CPU > 85 | 2  | Metric Alerts |  5 Minutes |  
|  AVD-VM-High CPU 95 Percent  | Percentage CPU > 95 | 1  | Metric Alerts |  5 Minutes |  
|  AVD-VM-Local Disk Free Space Warning 90 Percent  | AggregatedValue < 10 | 2  | Log Analytics Query |  15 Minutes |  
|  AVD-VM-Local Disk Free Space Warning 95 Percent  | AggregatedValue < 5 | 1  | Log Analytics Query |  15 Minutes |  

## Deploy via Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmain%2Fsolution.json)
[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmain%2Fsolution.json)

## Deploy from PowerShell
Consider using the script to build out your parameters file in the ./scripts folder. This will prompt for information and retrieve the needed resource IDs as well as create a timestamped pararmeters JSON file.  
[GetParamsInfo.PS1](./scripts/GetParamsInfo.ps1)

You will need the appropriate PowerShell modules installed and connected to Azure.  Then you can run the following from PowerShell:  
```PowerShell
New-AzResourceGroupDeployment -Name "AVD-Alerts-Solution" -TemplateFile https://raw.githubusercontent.com/JCoreMS/AVDAlerts/main/solution.json -TemplateParameterFile <YourParametersFile> -Location <region>
```
