@description('SKU code of the Azure Managed Lustre throughput configuration')
param lustreSku
  | 'AMLFS-Durable-Premium-40'
  | 'AMLFS-Durable-Premium-125'
  | 'AMLFS-Durable-Premium-250'
  | 'AMLFS-Durable-Premium-400' = 'AMLFS-Durable-Premium-400'

@description('TiB capacity for the Azure Managed Lustre')
param lustreStorageCapacity int = 4

var location = resourceGroup().location

var nsgName = 'lustreNSG'
var vnetName = 'lustreVnet'
var subnetName = 'lustreSubnet'
var fsName = 'lustreFS'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Internet'
        properties: {
          description: 'Open SSH inbound ports'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource lustreFs 'Microsoft.StorageCache/amlFilesystems@2024-03-01' = {
  name: fsName
  location: location
  sku: { name: lustreSku }
  properties: {
    filesystemSubnet: virtualNetwork.properties.subnets[0].id
    maintenanceWindow: {
      dayOfWeek: 'Saturday'
      timeOfDayUTC: '22:00'
    }
    storageCapacityTiB: lustreStorageCapacity
  }
  zones: [
    '1'
  ]
}

output virtualNetworkName string = virtualNetwork.name
output networkSecurityGroupName string = networkSecurityGroup.name
output mgsAddress string = lustreFs.properties.clientInfo.mgsAddress
