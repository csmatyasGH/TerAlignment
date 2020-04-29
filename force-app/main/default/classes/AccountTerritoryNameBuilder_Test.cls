@istest
public class AccountTerritoryNameBuilder_Test {
  @testsetup
  private static void setup() {
    List<System_Country_Validation_Record__c> countries = new List<System_Country_Validation_Record__c>();
    countries.add(
      new System_Country_Validation_Record__c(
        Name = 'United States',
        Country_Code__c = 'US',
        Region__c = 'DOMESTIC'
      )
    );
    countries.add(
      new System_Country_Validation_Record__c(
        Name = 'Argentina',
        Country_Code__c = 'AR',
        Region__c = 'LATAM'
      )
    );
    countries.add(
      new System_Country_Validation_Record__c(
        Name = 'Singapore',
        Country_Code__c = 'SG',
        Region__c = 'APAC'
      )
    );
    countries.add(
      new System_Country_Validation_Record__c(
        Name = 'Portugal',
        Country_Code__c = 'PT',
        Region__c = 'EMEA'
      )
    );

    insert countries;

    ID nodeRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('NODE')
      .getRecordTypeId();

    /************* create a 3 Nodes  take care of the RECORDTYpeID  ******************/
    TerritoryAllocator__c theTOPGEONODE1 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'TOP_GEO_NODE1',
        Geo__c = 'NORAM',
        Account_field__c = 'TerritoryGeo__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'NORAM',
        Validate__c = true,
        RecordTypeId = NodeRT
      ),
      true
    );
    TerritoryAllocator__c theSEGMENTNODE1 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'SEGMENT_NODE',
        Geo__c = 'NORAM',
        Account_field__c = 'TerritorySegment__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'HIED',
        ParentAllocator__c = theTOPGEONODE1.id,
        Validate__c = true,
        RecordTypeId = NodeRT
      ),
      true
    );
    TerritoryAllocator__c theBOTTOMNODE1 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'BOTTOM_NODE1',
        Geo__c = 'NORAM',
        Account_field__c = 'Org_Type__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'Corporate',
        ParentAllocator__c = theSEGMENTNODE1.id,
        Validate__c = true,
        isBottom__c = true,
        Territory_Name__c = 'NORAM HIED Central',
        Order_of_Execution__c = 301,
        RecordTypeId = NodeRT
      ),
      true
    );
    /************* create a 3 Node  ***********************************************/
  }

  /***********************************************************
AccountTerritoryNameBuilder(List<TerrBuilderWrapper> params)
***********************************************************/
  @isTest
  static void testInvokeAccountFindTerrName() {
    List<AccountTerritoryNameBuilder.TerrBuilderWrapper> params = new List<AccountTerritoryNameBuilder.TerrBuilderWrapper>();
    AccountTerritoryNameBuilder.TerrBuilderWrapper param = new AccountTerritoryNameBuilder.TerrBuilderWrapper();
    Account theA2M = new Account(Name = 'TestAcc');
    theA2M.TerritoryGeo__c = 'NORAM';
    theA2M.ShippingCountry = 'United States';
    theA2M.Org_Type__c = 'K12';
    theA2M.Primary_Business__c = 'K12';
    theA2M.ShippingPostalCode = '123456';
    theA2M = (Account) TestFactory.createSObject(theA2M, true);
    param.AccID2Align = theA2M.id;
    param.Operation = 'FindTerrName'; //CALL THE FLOW
    params.add(param);
    List<TerritoryAllocator__c> theTAs = AccountTerritoryNameBuilder.AccountTerritoryNameBuilder(
      params
    );

    theA2M.Primary_Business__c = 'Higher Ed';
    theA2M.Org_Type__c = 'Corporate';
    update theA2M;
    theTAs = AccountTerritoryNameBuilder.AccountTerritoryNameBuilder(params);
    System.assertEquals(
      1,
      theTAs.size(),
      'We expect ' +
      theTAs.size() +
      ' TerritoryAllocator.'
    );
  }

  @isTest
  static void testInvokeAccountBuildTerrName() {
    List<AccountTerritoryNameBuilder.TerrBuilderWrapper> params = new List<AccountTerritoryNameBuilder.TerrBuilderWrapper>();
    AccountTerritoryNameBuilder.TerrBuilderWrapper param = new AccountTerritoryNameBuilder.TerrBuilderWrapper();
    Account theA2M = new Account(Name = 'TestAcc');
    theA2M.TerritoryGeo__c = 'NORAM';
    theA2M.ShippingCountry = 'United States';
    theA2M.Org_Type__c = 'K12';
    theA2M.Primary_Business__c = 'K12';
    theA2M.ShippingPostalCode = '123456';
    theA2M = (Account) TestFactory.createSObject(theA2M, true);
    param.Accs2Process = theA2M;
    param.AccID2Align = theA2M.id;
    param.Operation = 'BuildTerrName'; //CALL THE PB
    params.add(param);
    List<TerritoryAllocator__c> theTAs = AccountTerritoryNameBuilder.AccountTerritoryNameBuilder(
      params
    );
    System.assertEquals(null, theTAs, 'No matching Allocator expected');
  }

  @isTest
  static void testInvokeAccount_AlignAcc()
  {
    List<AccountTerritoryNameBuilder.TerrBuilderWrapper> params = new List<AccountTerritoryNameBuilder.TerrBuilderWrapper>();
    AccountTerritoryNameBuilder.TerrBuilderWrapper param = WrapperBuilderHelper('AlignAcc'); 
    params.add(param);
    test.startTest();    
    Test.setMock(WebServiceMock.class, new AccountAllocatorCalloutMock());
    List<TerritoryAllocator__c> theTAs = AccountTerritoryNameBuilder.AccountTerritoryNameBuilder(params);
    Test.stopTest();
    System.assertNotEquals(null, theTAs, 'we get a fake Allocator for FLOW');
  }

  @isTest
  static void testInvokeAccount_Ready2Align()
  {
    List<AccountTerritoryNameBuilder.TerrBuilderWrapper> params = new List<AccountTerritoryNameBuilder.TerrBuilderWrapper>();
    AccountTerritoryNameBuilder.TerrBuilderWrapper param = WrapperBuilderHelper('ready2Align'); 
    params.add(param);
    test.startTest();    
    Test.setMock(WebServiceMock.class, new AccountAllocatorCalloutMock());
    List<TerritoryAllocator__c> theTAs = AccountTerritoryNameBuilder.AccountTerritoryNameBuilder(params);
    Test.stopTest();    
    System.assertEquals(null, theTAs, 'No matching Allocator expected');    
  }

  /***************************************************************************************************
  helper method to be invoked by above 2 test methods
  ***************************************************************************************************/
  private static AccountTerritoryNameBuilder.TerrBuilderWrapper WrapperBuilderHelper(String Operation)
  {
    AccountTerritoryNameBuilder.TerrBuilderWrapper param = new AccountTerritoryNameBuilder.TerrBuilderWrapper();
    Account theA2M = new Account(Name = 'TestAcc');
    theA2M.TerritoryGeo__c = 'NORAM';
    theA2M.ShippingCountry = 'United States';
    theA2M.Org_Type__c = 'K12';
    theA2M.Primary_Business__c = 'K12';
    theA2M.ShippingPostalCode = '123456';
    theA2M = (Account) TestFactory.createSObject(theA2M, true);
    param.Accs2Process = theA2M;
    param.AccID2Align = theA2M.id;
    param.Operation = Operation;

    return param;
  }

  /***************************************
  Create 1 Account try to edit some of its
  field
  **************************************/
  @isTest
  static void testEnrichAccount1() {
    Test.setMock(WebServiceMock.class, new AccountAllocatorCalloutMock()); //in case automatic alignment is triggered

    Account theA2M = new Account(Name = 'TestAcc');
    theA2M.TerritoryGeo__c = 'NORAM';
    theA2M.ShippingCountry = 'United States';
    theA2M.Org_Type__c = 'K12';
    theA2M.Primary_Business__c = 'K12';
    theA2M.ShippingPostalCode = '123456';
    theA2M = (Account) TestFactory.createSObject(theA2M, true);
    theA2M = [
      SELECT Id, Name, TerritoryGeo__c, TerritoryMarket__c, TerritorySegment__c
      FROM Account
      WHERE id = :theA2M.Id
    ];
    System.assertEquals(
      'NORAM',
      theA2M.TerritoryGeo__c,
      'Account trigger should not alter Geo'
    );
    System.assertEquals(
      'EDU',
      theA2M.TerritoryMarket__c,
      'We expect Market as EDU based on Account field configuration'
    );
    System.assertEquals(
      'K12',
      theA2M.TerritorySegment__c,
      'We expect Segment as K12 based on Account field configuration'
    );

    theA2M.Org_Type__c = 'Corporate';
    theA2M.Primary_Business__c = 'Non-Education';
    update theA2M;
    theA2M = [
      SELECT Id, Name, TerritoryGeo__c, TerritoryMarket__c, TerritorySegment__c
      FROM Account
      WHERE id = :theA2M.Id
    ];
    System.assertEquals(
      'CORP',
      theA2M.TerritoryMarket__c,
      'We expect Market as CORP based on Account field configuration'
    );

    theA2M.Primary_Business__c = 'Higher Ed';
    update theA2M;
    theA2M = [
      SELECT Id, Name, TerritoryGeo__c, TerritoryMarket__c, TerritorySegment__c
      FROM Account
      WHERE id = :theA2M.Id
    ];
    System.assertEquals(
      'HIED',
      theA2M.TerritorySegment__c,
      'We expect Segment as HIED based on Account field configuration'
    );

    theA2M.Primary_Business__c = 'K12';
    update theA2M;
    theA2M = [
      SELECT
        Id,
        Name,
        TerritoryGeo__c,
        TerritoryMarket__c,
        TerritorySegment__c,
        Primary_Business__c,
        Org_Type__c
      FROM Account
      WHERE id = :theA2M.Id
    ];
    System.assertEquals(
      'K12',
      theA2M.TerritorySegment__c,
      'We expect Segment as K12 based on Account field configuration'
    );

    theA2M.Org_Type__c = 'Corporate';
    theA2M.Primary_Business__c = 'Non-Education';
    update theA2M;
    theA2M = [
      SELECT
        Id,
        Name,
        TerritoryGeo__c,
        TerritoryMarket__c,
        TerritorySegment__c,
        Primary_Business__c,
        Org_Type__c
      FROM Account
      WHERE id = :theA2M.Id
    ];
    System.assertEquals(
      'MM',
      theA2M.TerritorySegment__c,
      'We expect Segment as MM based on Account field configuration'
    );

    theA2M.ShippingCountry = 'Argentina';
    update theA2M;
    theA2M = [
      SELECT
        Id,
        Name,
        TerritoryGeo__c,
        TerritoryMarket__c,
        TerritorySegment__c,
        Primary_Business__c,
        Org_Type__c
      FROM Account
      WHERE id = :theA2M.Id
    ];
    System.assertEquals(
      'NORAM',
      theA2M.TerritoryGeo__c,
      'Despite South America we expect NORAM due to Org_Type value'
    );

    theA2M.ShippingCountry = 'Singapore';
    theA2M.Primary_Business__c = 'Non-Education';
    update theA2M;
    theA2M = [
      SELECT
        Id,
        Name,
        TerritoryGeo__c,
        TerritoryMarket__c,
        TerritorySegment__c,
        Primary_Business__c,
        Org_Type__c
      FROM Account
      WHERE id = :theA2M.Id
    ];
    System.assertEquals(
      'APAC',
      theA2M.TerritoryGeo__c,
      'We expect Geo as APAC due to couuntry = Singapore'
    );
    System.assertEquals(
      'Non-Education',
      theA2M.Primary_Business__c,
      'Trigger should not alter Primary-Business field'
    );
    System.assertEquals(
      'Corporate',
      theA2M.Org_Type__c,
      'Trigger should not alter Org_type'
    );
    System.assertEquals(
      'CORP',
      theA2M.TerritorySegment__c,
      'Segment should be CORP due to Org_Type value'
    );

    theA2M.Org_Type__c = 'RTO/Training';
    update theA2M;
    theA2M = [
      SELECT
        Id,
        Name,
        TerritoryGeo__c,
        TerritoryMarket__c,
        TerritorySegment__c,
        Primary_Business__c,
        Org_Type__c
      FROM Account
      WHERE id = :theA2M.Id
    ];
    System.assertEquals(
      'RTO',
      theA2M.TerritorySegment__c,
      'Segment sould be RTO due to Org_Type value'
    );

    theA2M.ShippingCountry = 'Argentina';
    update theA2M;
    theA2M = [
      SELECT
        Id,
        Name,
        TerritoryGeo__c,
        TerritoryMarket__c,
        TerritorySegment__c,
        Primary_Business__c,
        Org_Type__c
      FROM Account
      WHERE id = :theA2M.Id
    ];
    System.assertEquals(
      'HIED',
      theA2M.TerritorySegment__c,
      'Segment should be HIED'
    );
    System.assertEquals(
      'LATAM',
      theA2M.TerritoryGeo__c,
      'GEO should be LATAM because of the Cocuntry and OrgType'
    );
  }

  /****************************************
When tried to test all in 1 function we
got CPU limit exced exception.
****************************************/
  @isTest
  static void testEnrichAccount2() {
    Account theA2M = new Account(Name = 'TestAcc2');
    theA2M.TerritoryGeo__c = 'APAC';
    theA2M.ShippingCountry = 'Singapore';
    theA2M.Org_Type__c = 'K12';
    theA2M.Primary_Business__c = 'Non-Education';
    theA2M = (Account) TestFactory.createSObject(theA2M, true);
    theA2M = [
      SELECT Id, Name, TerritoryGeo__c, TerritoryMarket__c, TerritorySegment__c
      FROM Account
      WHERE id = :theA2M.Id
    ];

    System.assertEquals(
      'APAC',
      theA2M.TerritoryGeo__c,
      'GEO should be APAC due to country value'
    );
    System.assertEquals(
      'K12',
      theA2M.TerritorySegment__c,
      'Segment should follow Org_Type value'
    );

    theA2M.Org_Type__c = 'Higher Ed';
    update theA2M;
    theA2M = [
      SELECT
        Id,
        Name,
        TerritoryGeo__c,
        TerritoryMarket__c,
        TerritorySegment__c,
        Primary_Business__c,
        Org_Type__c
      FROM Account
      WHERE id = :theA2M.Id
    ];
    System.assertEquals(
      'HIED',
      theA2M.TerritorySegment__c,
      'Segment should follow Org_Type value'
    );
  }
}