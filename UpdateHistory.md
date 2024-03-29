# Update History

4/14/23

- Version 2.0 Release consolidates the need for Enterprise versus Subscription deployments yet allows resources in separate Subscriptions
- Added UI Definition for ease of deployment vs running scripts  
- All VM alerts are now revised which will create separate ones for each Host Pool thus allowing separate groups to be alerted for specific host pool VM resources and their health (deployment script creates AVD Host Pool to VM resource mapping)
- Documentation updated to reflect changes and additional description information added to alerts
- Corrected queries for "Profile Disk n% full" as these would potentially never fire or alert

```sql
prefix-VM-FSLogix Profile Less Than 2% Free Space  
| where EventLevelName == "Error"  
| where EventID == 33  

prefix-VM-FSLogix Profile Less Than 5% Free Space
| where EventLevelName == "Warning"
| where EventID == 34
```

1/11/23

- Deploy scripts now allow custom, existing Resource Group input
- Corrected issue where Log Analtyics role assignment needed for Enterprise deployment (Tenant Level)
- Minor deploy script updates for ease of use

1/4/23

- Added AVD Service Health alerts (Only deployed for Azure Commercial as not yet available in Azure US Gov)
- Updated deployment scripts to allow multiple selection for Azure Files and ANF resources
- Updated documentation for added alerts

12/22/22

- Correct issue with ARM templates due to missing URI for Logic App HTTP action (See Issues for details)

12/8/22

- Updated Azure File Share Info Runbook Script to resolve authentication issues when Storage Network Firewall settings specify Specific VNets
- Re-enable Logic App and Runbook deployments and add Azure Files based alerts back to solution and update documentation
- Remove Data Access Read Role and change to Storage Account Contributor

12/6/22  

- Removed Logic App and Runbook for getting Azure File Share storage account information due to failures if Networking has anything other than "Enabled from all Networks" configured.  
- Added additional alerts for storage latency and adjusted from 200ms to separate alerts at 100ms and 50ms for End to End and Storage specific.  
- Fixed issue with Tags not be created for every resource.  
- Health check failure alerts frequency adjusted from 5 to 15 min intervals to accommodate for false alerts during deployment/ maintenance.  
- FSLogix Profile failures now split out into alerts based on common event log entries (more specific)
- Informational alert added for Host Pool Capacity at 50%
- Host Pool Capacity Alerts - updated to only report between thresholds to prevent duplicates

12/5/22

- Update FSLogix alerts

10/20/22  

- Revised deployment to utilize PowerShell vs Blue button in docs due to storage account parameter type
