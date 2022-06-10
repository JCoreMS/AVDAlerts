param Name string = 'profiles'

resource Resource 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' existing = {
  name: Name
  scope: resourceGroup('rg-eastus2-avdlab-manage')
}

output Info object = Resource.properties


// What do we need to collect in Params (All Same Sub)
/*
RG
Storage Acct
Share Name

Alert Naming Standard
AVD-Storage-VolumeAt80Percent-
AVD-VM
AVD-Network
AVD-HostPool


*/

