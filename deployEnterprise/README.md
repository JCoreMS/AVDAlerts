# AVD Alerts Solution

[Home](./README.md) | [PostDeployment](./PostDeploy.md) | [How to Change Thresholds](./ChangeAlertThreshold.md) | [Alert Query Reference](./AlertQueryReference.md) | [Excel List of Alert Rules](https://github.com/JCoreMS/AVDAlerts/raw/main/references/alerts.xlsx)

## Description

This solution provides a baseline of alerts for AVD that are disabled by default and for ensuring administrators and staff get meaningful and timely alerts when there are problems related to an AVD deployment. The deployment has been tested in Azure Global and Azure US Government and will incorporate storage alerts for either or both Azure Files and/or Azure Netapp Files.

## Prerequisites  

Global Admin at the Tenant level.

## Deploy

You will need the appropriate PowerShell modules installed and connected to Azure.  Then you can run the following from PowerShell:  

```PowerShell
New-AzTenantDeployment -Name "AVD-Alerts-Solution" -TemplateUri https://raw.githubusercontent.com/JCoreMS/AVDAlerts/JCore-TenantDeploy-9.2.22/deployEnterprise/tenant.solution.json -TemplateParameterFile tenant.solution.parameters.json -Location <region>
```

__See [PostDeployment](../PostDeploy.md) for next steps to enable and view alerts.__
