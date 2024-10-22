targetScope = 'subscription'

@description('Name of the resource group')
param resourceGroupName string = 'lustreGroup'

@description('Location of all resources')
param resourceGroupLocation string

@description('SSH Key to access the created Virtual Machines')
@secure()
param sshKey string

var clusterSize = 10

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: resourceGroupLocation
}

module lustre 'lustre.bicep' = {
  name: 'lustre'
  scope: rg
}

module mainVM 'vm.bicep' = {
  name: 'mainVM'
  scope: rg
  params: {
    networkSecurityGroupName: lustre.outputs.networkSecurityGroupName
    virtualNetworkName: lustre.outputs.virtualNetworkName
    sshKey: sshKey
    vmName: 'lustre-main'
    vmSize: 'Standard_D2_v4'
    public: true
  }
}

module computeVms 'vm.bicep' = [for i in range(0, clusterSize): {
    name: 'computeVM${i}'
    scope: rg
    params: {
      networkSecurityGroupName: lustre.outputs.networkSecurityGroupName
      virtualNetworkName: lustre.outputs.virtualNetworkName
      sshKey: sshKey
      vmName: 'computeVM-${i}'
      vmSize: 'Standard_D2_v4'
    }
}]

output mainVmSshAddress string = mainVM.outputs.sshAddress
output computeVms array = [for i in range(0, clusterSize): {
  name: computeVms[i].name
  sshAddress: computeVms[i].outputs.sshAddress
}]
