# AVD Alerts Solution

[Home](./README.md) | [PostDeployment](./PostDeploy.md) | [How to Change Thresholds](./ChangeAlertThreshold.md) | [Alert Reference](./AlertReference.md) | [Excel List of Alert Rules](https://github.com/JCoreMS/AVDAlerts/raw/main/references/alerts.xlsx) | [Update History](./UpdateHistory.md)

## Description

This solution provides a baseline of alerts for AVD that are disabled by default and for ensuring administrators and staff get meaningful and timely alerts when there are problems related to an AVD deployment. The deployment has been tested in Azure Global and Azure US Government and will incorporate storage alerts for either or both Azure Files and/or Azure Netapp Files.

## Prerequisites  

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

| Name                                                                      | Threshold(s) (Severity)    |  Signal Type   |  Frequency    |  # Alert Rules |
|---                                                                        |---                         |---             |---            |---  
| AVD-HostPool-Capacity :one:                                               | 95% (1) / 85% (2) / 50% (3)| Log Analytics  |  5 min        |  3/hostpool |
| AVD-HostPool-Disconnected User over n Hours (hostpoolname)                | 24 (1) / 72 (2)            | Log Analytics  |  1 hour       |  2/hostpool |
| AVD-HostPool-No Resources Available (hostpoolname)                        | Any are Sev1               | Log Analytics  |  15 min       |  1/hostpool |
| AVD-HostPool-VM-Available Memory Less Than nGB (hostpoolname)             | 1gb (Sev1) / 2gb (Sev2)    | Metric Alerts  |  5 min        |  2/hostpool |
| AVD-HostPool-VM-FSLogix Profile DiskCompactFailed (hostpoolname)          | (2)                        | Log Analytics  |  5 min        |  1/hostpool |
| AVD-HostPool-VM-FSLogix Profile FailedAttachVHD (hostpoolname)            | (1)                        | Log Analytics  |  5 min        |  1/hostpool |
| AVD-HostPool-VM-FSLogix Profile Less Than n% Free Space (hostpoolname)    | 2% (1) / 5% (2)            | Log Analytics  |  5 min        |  2/hostpool |
| AVD-HostPool-VM-FSLogix Profile Failed due to Network Issue (hostpoolname)| (1)                        | Log Analytics  |  5 min        |  1/hostpool |
| AVD-HostPool-VM-FSLogix Profile Service Disabled (hostpoolname)           | (1)                        | Log Analytics  |  5 min        |  1/hostpool |
| AVD-HostPool-VM-Health Check Failure (hostpoolname)                       | (1)                        | Log Analytics  |  5 min        |  1/hostpool |
| AVD-HostPool-VM-High CPU nn Percent (hostpoolname)                        | 95 (1) / 85 (2)            | Metric Alerts  |  5 min        |  2/hostpool |
| AVD-HostPool-VM-Local Disk Free Space n% (hostpoolname)                   | 5 (1) / 10 (2)             | Log Analytics  |  15 min       |  2/hostpool |
| AVD-Storage-Low Space on ANF Share-XX Percent Remaining-{volumename}      | 5 / 15                     | Metric Alerts  |  1 hour       |  2/vol  |
| AVD-Storage-Low Space on Azure File Share-X% Remaining-{volumename} :one: | 5 / 15                     | Log Analytics  |  1 hour       |  2/share  |
| AVD-Storage-Over XXms Latency for Storage Act-{storacctname}              | 100ms / 50ms               | Metric Alerts  |  15 min       |  2/stor acct |
| AVD-Storage-Over XXms Latency Between Client-Storage-{storacctname}       | 100ms / 50ms               | Metric Alerts  |  15 min       |  2/stor acct |
| AVD-Storage-Possible Throttling Due to High IOPs-{storacctname}           | na / custom :two:          | Metric Alerts  |  15 min       |  1/stor acct |
| AVD-Storage-Azure Files Availability-{storacctname}                       | 99 / na                    | Metric Alerts  |  5 min        |  1/stor acct |
| AVD-ServiceHealth-Health Advisory                                         | na                         | Service Health |  na           |   4  |
| AVD-ServiceHealth-Planned Maintenance                                     | na                         | Service Health |  na           |   4  |
| AVD-ServiceHealth-Security                                                | na                         | Service Health |  na           |   4  |
| AVD-ServiceHealth-Service Issue                                           | na                         | Service Health |  na           |   4  |

**NOTES:**  
:one: Alert based on associated Logic App and Runbook  
:two: See the following for custom condition. Note that both Standard and Premium values are incorporated into the alert rule. ['How to create an alert if a file share is throttled'](https://docs.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-performance#how-to-create-an-alert-if-a-file-share-is-throttled)  
Service Health - The alert severity cannot be set or changed from 'Verbose'  

[**Alert Reference**](AlertReference.md)

## Deployment / Installation

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmaster%2Fsolution.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmaster%2FUIdefinition.json)  [![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmaster%2Fsolution.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FJCoreMS%2FAVDAlerts%2Fmaster%2FUIdefinition.json)

### [PostDeployment](./PostDeploy.md)

See the above linked section for information on how to enable and view the alerts created.
