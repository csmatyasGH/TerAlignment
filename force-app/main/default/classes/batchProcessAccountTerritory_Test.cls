@istest
public class batchProcessAccountTerritory_Test {
  @testSetup
  static void testSetup() {
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

    ID nodeRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByName()
      .get('NODE')
      .getRecordTypeId();

    /****************************************** create a 3 Nodes  **************************/
    TerritoryAllocator__c theTOPGEONODE1 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'TOP_GEO_NODE1',
        Geo__c = 'NORAM',
        Account_field__c = 'TerritoryGeo__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'NORAM',
        Validate__c = true,
        RecordTypeId = nodeRT
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
        Territory_Name__c = 'NORAM HIED Great Lakes',
        Order_of_Execution__c = 301,
        RecordTypeId = NodeRT
      ),
      true
    );
    /******************************************* create a 3 Node  ***********************************************/

    //create 1 account which match
    Account theA2M = new Account(Name = 'TestAccM');
    theA2M.TerritoryGeo__c = 'NORAM';
    theA2M.ShippingCountry = 'United States';
    theA2M.Org_Type__c = 'Corporate';
    theA2M.ShippingPostalCode = '123456';
    theA2M.TerritorySegment__c = 'HIED';
    theA2M = (Account) TestFactory.createSObject(theA2M, true);
    System.assertEquals(true, theA2M.id != null, 'Account should exist');

    //create 1 account which does not match
    Account theA2NM = new Account(Name = 'TestAccNM');
    theA2NM.TerritoryGeo__c = 'NORAM';
    theA2NM.ShippingCountry = 'United States';
    theA2NM.Org_Type__c = 'K12';
    theA2NM.ShippingPostalCode = '234561';
    theA2NM.TerritorySegment__c = 'HIED';
    theA2NM = (Account) TestFactory.createSObject(theA2NM, true);
    System.assertEquals(true, theA2NM.id != null, 'Account should exist');
  }

  @isTest
  static void testbatchAllocatorExecute() {
    Batch_Job_Monitor__c headeru = new Batch_Job_Monitor__c();
    headeru.BatchClassName__c = 'batchProcessAccountTerritory';
    headeru.Active__c = true;
    headeru.Log_Level__c = 'High';
    insert headeru;

    //create 1 account which is frozen
    Account theAF = new Account(Name = 'TestAccF');
    theAF.TerritoryGeo__c = 'NORAM';
    theAF.ShippingCountry = 'United States';
    theAF.Org_Type__c = 'Other';
    theAF.ShippingPostalCode = '654321';
    theAF.TerritorySegment__c = 'K12';
    theAF.temp_AllocatorID__c = 'NORAM K12 East/EDU/K12';
    theAF = (Account) TestFactory.createSObject(theAF, true);
    System.assertEquals(
      true,
      theAF.id != null,
      'Account should have been created'
    );

    //add oportunity to this Account
    Opportunity theO = new Opportunity();
    theO.AccountId = theAF.id;
    theO.stageName = 'Needs Approval';
    theO.CloseDate = System.Date.today().addDays(2);
    theO = (Opportunity) TestFactory.createSObject(theO, true);

    List<TerritoryAllocator__c> tas = [SELECT id FROM TerritoryAllocator__c];
    system.assertEquals(
      3,
      tas.size(),
      'We check if the 3 Allocator records were created succesfully in TestSetup'
    );

    batchProcessAccountTerritory batchu;
    Test.startTest();

    batchu = new batchProcessAccountTerritory('NORAM', null, null);
    DataBase.executeBatch(batchu);

    Test.stopTest();

    List<Account> accs = [
      SELECT
        Id,
        Name,
        TerritoryName_Suggested__c,
        temp_AllocatorID__c,
        Need_Alignment__c,
        TerritoryMarket__c,
        TerritoryTeam__c,
        TerritorySegment__c,
        FreezeAlignment__c
      FROM Account
    ];

    //iterate through the accounts and Assert TerritoryName suggested__c field.
    //Pass accoutn as assert 3-rd parameter to see the value in case of failure
    for (Account acc : accs) {
      if (acc.Name == 'TestAccM') {
        system.assertEquals(
          acc.TerritoryName_Suggested__c == 'NORAM HIED Great Lakes',
          true,
          acc
        );
        system.assertEquals(acc.Need_Alignment__c, true, acc);
      } else if (acc.Name == 'TestAccNM') {
        system.assertEquals(
          acc.TerritoryName_Suggested__c == 'MISSED',
          true,
          acc
        );
      } else if (acc.Name == 'TestAccF') {
        system.assertEquals(acc.FreezeAlignment__c, true, acc);
        system.assertEquals(
          acc.TerritoryTeam__c == 'NORAM K12 East',
          true,
          acc
        );
        system.assertEquals(acc.TerritoryMarket__c == 'EDU', true, acc);
        system.assertEquals(acc.TerritorySegment__c == 'K12', true, acc);
      }
    }
  }

  /********************************************
test platform event trigger to generate error
in the START method of the BATCH
********************************************/
  @isTest
  static void testBatchApexErrorEvent() {
    Batch_Job_Monitor__c headeru = new Batch_Job_Monitor__c();
    headeru.BatchClassName__c = 'batchProcessAccountTerritory';
    headeru.Active__c = true;
    headeru.Log_Level__c = 'High';
    insert headeru;
    system.assertNotEquals(null, headeru.id, 'Header should exist in database');

    batchProcessAccountTerritory batchu;
    ID batchAsynchID;
    try {
      Test.startTest();
      batchu = new batchProcessAccountTerritory(null, null, -1);
      batchAsynchID = DataBase.executeBatch(batchu);
      Test.stopTest();
    } catch (Exception myEx) {
      System.Assert(
        true,
        'We do not care about the detail here. we assert at the bottom'
      );
    }
    Test.getEventBus().deliver();

    List<Batch_Job_Monitor_Item__c> bjmis = [
      SELECT id, Message__c, Parent_Job_Monitor__c
      FROM Batch_Job_Monitor_Item__c
    ];
    System.assertEquals(
      1,
      bjmis.size(),
      'Expect 1 Batch Job momitor Item due to exception'
    );
  }
}