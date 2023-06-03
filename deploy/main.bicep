@description('The location into which the Azure resources should be deployed.')
param location string = resourceGroup().location

@description('The name of the container registry to create. This must be globally unique.')
param containerRegistryName string = 'shir${uniqueString(resourceGroup().id)}'

@description('The name of the virtual network to create.')
param vnetName string = 'shirdemo'

@description('The name of the data factory to create. This must be globally unique.')
param dataFactoryName string = 'shirdemo${uniqueString(resourceGroup().id)}'

@description('The name of the SKU to use when creating the virtual machine.')
param vmSize string = 'Standard_DS1_v2'

@description('The type of disk and storage account to use for the virtual machine\'s OS disk.')
param vmOSDiskStorageAccountType string = 'StandardSSD_LRS'

@description('The administrator username to use for the virtual machine.')
param vmAdminUsername string = 'shirdemoadmin'

@description('The administrator password to use for the virtual machine.')
@secure()
param vmAdminPassword string

@description('The name of ACI to create. This must be globally unique.')
param aciName string = 'shir${uniqueString(resourceGroup().id)}'

// Deploy the container registry and build the container image.
module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    name: containerRegistryName
    location: location
  }
}

// Deploy a virtual network with the subnets required for this solution.
module vnet 'modules/vnet.bicep' = {
  name: 'vnet'
  params: {
    name: vnetName
    location: location
  }
}

// Deploy a virtual machine with a private web server.
var vmImageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2019-Datacenter'
  version: 'latest'
}

module vm 'modules/vm.bicep' = {
  name: 'vm'
  params: {
    location: location
    subnetResourceId: vnet.outputs.vmSubnetResourceId
    vmSize: vmSize
    vmImageReference: vmImageReference
    vmOSDiskStorageAccountType: vmOSDiskStorageAccountType
    vmAdminUsername: vmAdminUsername
    vmAdminPassword: vmAdminPassword
  }
}

// Deploy the data factory.
module adf 'modules/data-factory.bicep' = {
  name: 'adf'
  params: {
    dataFactoryName: dataFactoryName
    location: location
    virtualNetworkName: vnet.outputs.virtualNetworkName
    dataFactorySubnetResourceId: vnet.outputs.dataFactorySubnetResourceId
  }
}

// Deploy a Data Factory pipeline to connect to the private web server on the VM.
module dataFactoryPipeline 'modules/data-factory-pipeline.bicep' = {
  name: 'adf-pipeline'
  params: {
    dataFactoryName: adf.outputs.dataFactoryName
    integrationRuntimeName: adf.outputs.integrationRuntimeName
    virtualMachinePrivateIPAddress: vm.outputs.virtualMachinePrivateIPAddress
  }
}


var image = '${acr.outputs.containerRegistryName}.azurecr.io/${acr.outputs.containerImageName}:${acr.outputs.containerImageTag}'

// TODO: how to deploy without assigning ports twice?
module aci 'modules/aci.bicep' = {
  name: 'aci'
  params: {
    name: aciName
    location: location
    // Fails if enabled: 'Managed service identity is not supported for Windows container groups.'
    systemAssignedIdentity: false
    containers: [
      {
        name: '1'
        properties: {
          command: []
          environmentVariables: [
            {
              name: 'AUTH_KEY'
              secureValue: adf.outputs.irKey
            }
            {
              name: 'NODE_NAME'
              value: 'demonode'
            }
            {
              name: 'ENABLE_AE'
              value: 'true'
            }
            {
              name: 'AE_TIME'
              value: '601'
            }
            {
              name: 'ENABLE_HA'
              value: 'true'
            }
          ]
          image: image
          ports: [
            {
              port: 80
              protocol: 'Tcp'
            }
            {
              port: 443
              protocol: 'Tcp'
            }
          ]
          resources: {
            requests: {
              cpu: 4
              memoryInGB: 8
            }
          }
        }
      }
    ]
    ipAddressType: 'Private'
    subnetId: vnet.outputs.aciSubnetResourceId
    ipAddressPorts: [
      {
        port: 80
        protocol: 'Tcp'
      }
      {
        port: 443
        protocol: 'Tcp'
      }
    ]
    osType: 'Windows'
    restartPolicy: 'OnFailure'
    sku: 'Standard'
    // No support for MSI, service principal requires too much work for being demo
    imageRegistryCredentials: [
      {
        server: acr.outputs.loginServer
        username: acr.outputs.username
        password: acr.outputs.password
      }
    ]
  }
}


module adfRoleAssignments 'modules/data-factory-role-assingments.bicep' = {
  name: 'adfRoleAssignments'
  params: {
    aciName:  aciName
    adfMsiId: adf.outputs.msiId
    adfName: dataFactoryName
  }
  dependsOn: [
    adf
    aci
  ]
}
