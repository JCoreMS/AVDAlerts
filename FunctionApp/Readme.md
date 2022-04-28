## PRE-REQS

AVD Host Pools & Log Analytics Workspace

## Import Custom Role

- Allows write to Log Analytics Workspace (CustomRole-Write2LAW.json)  
  (Not covered by Owner or Contributor)

## Function App

Update Script with the required values:  
- Initial Subscription Name
- Tag Value and Key

Create System Managed Identity and assign Roles
- Apply Custom Role to Log Analytics Workspace
- Apply Reader at Subscription(s)