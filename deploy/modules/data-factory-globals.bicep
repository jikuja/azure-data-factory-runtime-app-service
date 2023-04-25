@description('ACI id')
param aciId string

@description('ADF name')
param adfName string

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: adfName
}

resource globalParameters 'Microsoft.DataFactory/factories/globalParameters@2018-06-01' = {
  name: 'default'
  parent: dataFactory
  properties: {
    aciId: {
      type: 'String'
      value: aciId
    }
    adfId: {
      type: 'String'
      value: dataFactory.id
    }
  }
}

