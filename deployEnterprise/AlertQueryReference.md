[Home](./README.md) | [PostDeployment](./PostDeploy.md) | [How to Change Thresholds](./ChangeAlertThreshold.md) | [Alert Query Reference](./AlertQueryReference.md) | [Excel List of Alert Rules](https://github.com/JCoreMS/AVDAlerts/raw/main/references/alerts.xlsx)

# Alert Query Reference

The following are the queries used in the solution.  

## AVD-HostPool-Capacity-XXPercent

This query is also based on the output of the Runbook for AVD Host Pool information that is the AzureDiagnostics table.

```
AzureDiagnostics 
| where Category has "JobStreams" and StreamType_s == "Output" and RunbookName_s == "AvdHostPoolLogData"
| sort by TimeGenerated
| where TimeGenerated > now() - 5m
| extend HostPoolName=tostring(split(ResultDescription, '|')[0])
| extend ResourceGroup=tostring(split(ResultDescription, '|')[1])
| extend Type=tostring(split(ResultDescription, '|')[2])
| extend MaxSessionLimit=toint(split(ResultDescription, '|')[3])
| extend NumberSessionHosts=toint(split(ResultDescription, '|')[4])
| extend UserSessionsTotal=toint(split(ResultDescription, '|')[5])
| extend UserSessionsDisconnected=toint(split(ResultDescription, '|')[6])
| extend UserSessionsActive=toint(split(ResultDescription, '|')[7])
| extend UserSessionsAvailable=toint(split(ResultDescription, '|')[8])
| extend HostPoolPercentLoad=toint(split(ResultDescription, '|')[9])
| where HostPoolPercentLoad >= 85  //value to use for percentage       
```

## AVD-HostPool-Disconnected User over XX Hours

```
// Session duration 
// Lists users by session duration in the last 24 hours. 
// The "State" provides information on the connection stage of an actitivity.
// The delta between "Connected" and "Completed" provides the connection time for a specific connection.
WVDConnections 
| where TimeGenerated > ago(24h) 
| where State == "Connected"  
| project
    CorrelationId,
    UserName,
    ConnectionType,
    StartTime=TimeGenerated,
    SessionHostName
| join (WVDConnections  
    | where State == "Completed"  
    | project EndTime=TimeGenerated, CorrelationId)  
    on CorrelationId  
| project Duration = EndTime - StartTime, ConnectionType, UserName, SessionHostName
| where Duration >= timespan(24:00:00)
| sort by Duration desc
```

## AVD-HostPool-No Resources Available

```
WVDConnections 
| where TimeGenerated > ago (15m) 
| project-away TenantId, SourceSystem  
| summarize
    arg_max(TimeGenerated, *),
    StartTime =  min(iff(State == 'Started', TimeGenerated, datetime(null))),
    ConnectTime = min(iff(State == 'Connected', TimeGenerated, datetime(null)))
    by CorrelationId  
| join kind=leftouter (WVDErrors
    | summarize Errors=makelist(pack('Code', Code, 'CodeSymbolic', CodeSymbolic, 'Time', TimeGenerated, 'Message', Message, 'ServiceError', ServiceError, 'Source', Source)) by CorrelationId  
    )
    on CorrelationId
| join kind=leftouter (WVDCheckpoints
    | summarize Checkpoints=makelist(pack('Time', TimeGenerated, 'Name', Name, 'Parameters', Parameters, 'Source', Source)) by CorrelationId  
    | mv-apply Checkpoints on (  
        order by todatetime(Checkpoints['Time']) asc
        | summarize Checkpoints=makelist(Checkpoints)
        )
    )
    on CorrelationId  
| project-away CorrelationId1, CorrelationId2  
| order by TimeGenerated desc
| where Errors[0].CodeSymbolic == "ConnectionFailedNoHealthyRdshAvailable"
```

## AVD-Storage-Low Space on Azure File Share-XX% Remaining

This query is also based on the output of the Runbook for Azure Files and ANF Storage information that is the AzureDiagnostics table.

```
AzureDiagnostics 
| where Category has "JobStreams"
    and StreamType_s == "Output"
    and RunbookName_s == "AvdStorageLogData"
| sort by TimeGenerated
//  StorageType / Subscription / RG / StorAcct / Share / Quota / GB Used / %Available
| extend StorageType=split(ResultDescription, ',')[0]
| extend Subscription=split(ResultDescription, ',')[1]
| extend ResourceGroup=split(ResultDescription, ',')[2]
| extend StorageAccount=split(ResultDescription, ',')[3]
| extend Share=split(ResultDescription, ',')[4]
| extend GBShareQuota=split(ResultDescription, ',')[5]
| extend GBUsed=split(ResultDescription, ',')[6]
| extend PercentAvailable=split(ResultDescription, ',')[7]
| where PercentAvailable <= 15.00 and PercentAvailable < 5.00  
```

## AVD-VM-FSLogix Profile Failed (Event Log Indicated Failure)

```
Event
| where EventLog == "Microsoft-FSLogix-Apps/Admin"
| where EventLevelName == "Error"
```

## AVD-VM-Local Disk Free Space XX% Remaining

```
Perf
| where TimeGenerated > ago(15m)
| where ObjectName == "LogicalDisk" and CounterName == "% Free Space"
| where InstanceName !contains "D:"
| where InstanceName !contains "_Total"
| where CounterValue <= 10.00
```
