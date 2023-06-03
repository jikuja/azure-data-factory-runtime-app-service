resource aciRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource adfRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

@description('ADF name')
param adfName string

@description('ADF MSI id')
param adfMsiId string

@description('ACI name')
param aciName string

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: adfName
}

resource aci 'Microsoft.ContainerInstance/containerGroups@2022-09-01' existing = {
  name: aciName
}

resource adfRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: dataFactory
  name: guid(dataFactory.id, adfMsiId, aciRole.id)
  properties: {
    roleDefinitionId: adfRole.id
    principalId: adfMsiId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: aci
  name: guid(aci.id, adfMsiId, aciRole.id)
  properties: {
    roleDefinitionId: aciRole.id
    principalId: adfMsiId
    principalType: 'ServicePrincipal'
  }
}
