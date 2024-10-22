
@description('Location of all resources')
param location string = resourceGroup().location

@description('Name of the Virtual Machine')
param vmName string

@description('Name of the administrator account in the VM')
param adminUsername string = 'ubuntu'

@description('SSH Key for the Virtual Machine')
@secure()
param sshKey string

@description('Name of the Virtual network')
param virtualNetworkName string

@description('Name of the Network Security Group')
param networkSecurityGroupName string

@description('Deploy a jump machine with a public IP and SSH access')
param public bool = false

@description('Vm size')
param vmSize string



var publicIpAddressName = '${vmName}PublicIP'

var networkInterfaceName = '${vmName}NetInt'

var osDiskType = 'Standard_LRS'

var dnsLabelPrefix = toLower('${vmName}-${uniqueString(resourceGroup().id)}')

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: virtualNetworkName
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-11-01' existing = {
  name: networkSecurityGroupName
}


resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = if (public) {
  name: publicIpAddressName
  location: location
  sku: {name: 'Basic'}
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
    idleTimeoutInMinutes: 4
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: public ? {
            id: publicIPAddress.id
          } : null
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
    enableAcceleratedNetworking: true
  }
}


resource ubuntuVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}

output sshAddress string = public ? '${adminUsername}@${publicIPAddress.properties.dnsSettings.fqdn}' : '${adminUsername}@${networkInterface.properties.ipConfigurations[0].properties.privateIPAddress}'
