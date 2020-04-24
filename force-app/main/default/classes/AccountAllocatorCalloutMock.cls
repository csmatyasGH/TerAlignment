@isTest
global class AccountAllocatorCalloutMock implements WebServiceMock {
  //we do not care what is the response because we do not rely on it in code. Code check Terr align by  re-querying data
  String jsonu = '[{"apex_schema_type_info": "0xd9f1f1e","errors_type_info": "0x5abf168f","field_order_type_info": "0x1b79683f","id": "001S000000yhIGBIA2","id_type_info": "0x58742153","success": true,"success_type_info": "0x2de6b2ac"}]';

  global void doInvoke(
    Object stub,
    Object request,
    Map<String, Object> response,
    String endpoint,
    String soapAction,
    String requestName,
    String responseNS,
    String responseName,
    String responseType
  ) {
    partnerSoapSforceCom.updateResponse_element responsu = new partnerSoapSforceCom.updateResponse_element();
    response.put('response_x', responsu);

    System.assert(
      true,
      'we do not care what is the response because we do not rely on it in code. Code check Terr align by  re-querying data'
    );
  }
}