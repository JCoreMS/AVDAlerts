# Update History

12/22/22

- Correct issue with ARM templates due to missing URI for Logic App HTTP action (See Issues for details)

12/5/22

- Update FSLogix alerts

10/20/22  

- Revised deployment to utilize PowerShell vs Blue button in docs due to storage account parameter type.  

12/6/22  

- Removed Logic App and Runbook for getting Azure File Share storage account information due to failures if Networking has anything other than "Enabled from all Networks" configured.  
- Added additional alerts for storage latency and adjusted from 200ms to separate alerts at 100ms and 50ms for End to End and Storage specific.  
- Fixed issue with Tags not be created for every resource.  
- Health check failure alerts frequency adjusted from 5 to 15 min intervals to accommodate for false alerts during deployment/ maintenance.  
- FSLogix Profile failures now split out into alerts based on common event log entries (more specific)
- Informational alert added for Host Pool Capacity at 50%
- Host Pool Capacity Alerts - updated to only report between thresholds to prevent duplicates

12/8/22

- Updated Azure File Share Info Runbook Script to resolve authentication issues when Storage Network Firewall settings specify Specific VNets
- Re-enable Logic App and Runbook deployments and add Azure Files based alerts back to solution and update documentation
- Remove Data Access Read Role and change to Storage Account Contributor
