## PRE-REQS

AVD Host Pools & Log Analytics Workspace
Account with Owner role on Subscription

## Function App
Created as part of the deployment with the following required parameters:
- Resource Group to place Function App resources
- Location/Region where resources reside and for solution deployment
- Log Analytics Workspace Name being used for AVD Insights
- Resource Group(s) in which Host Pool 'type' resources reside (not necessarily the VM specific resources)

What is deployed:
Resource Group for Function App
- Function App
- Storage Account
- App Service Plan
Custom Role for writing Metrics to Log Analytics workspace
- Assigned at Subscription Level
- 