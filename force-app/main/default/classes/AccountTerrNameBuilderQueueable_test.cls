@istest
public class AccountTerrNameBuilderQueueable_test {
  @isTest
  static void testmatchingNode() {
    ID allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('NODE')
      .getRecordTypeId();
    TerritoryAllocator__c theTA = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Geo__c = 'NORAM',
        Account_field__c = 'TerritoryGeo__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'NORAM',
        RecordTypeId = allocRT
      ),
      true
    );

    Account theA2M = new Account(Name = 'TestAcc');
    theA2M.TerritoryGeo__c = 'NORAM';
    theA2M.TerritorySegment__c = 'HIED';
    theA2M.ShippingState = 'Alabama';
    theA2M.Org_Type__c = 'Corporate';
    theA2M.Account_FTE__c = 200;

    Boolean hasMatch = AccountTerrNameBuilderQueueable.matchingNode(
      theA2M,
      theTA
    );
    System.AssertEquals(true, hasMatch, 'We expect match');

    theTA.Operator__c = 'NOT_EQUAL';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    // inner match Sao Paolo vs. Greater Sao Paolo
    theTA.Account_field__c = 'ShippingState';
    theTA.Operator__c = 'IN';
    theTA.Comparison_Value__c = 'Alabama,Arkansas';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'We expect match');

    theTA.Account_field__c = 'ShippingState';
    theTA.Operator__c = 'IN';
    theTA.Comparison_Value__c = 'test1,Arkansas';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theA2M.ShippingState = 'the Alabama';
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theA2M.ShippingState = 'Alabama state';
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theTA.Operator__c = 'NOT_IN';
    theTA.Comparison_Value__c = 'state1,state2';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'We expect match');

    theA2M.ShippingState = 'Alabama';
    theTA.Operator__c = 'NOT_IN';
    theTA.Comparison_Value__c = 'Alabama,state2';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theTA.Account_field__c = 'Account_FTE__c';
    theTA.Operator__c = 'GREATER';
    theTA.Comparison_Value__c = '10';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'We expect match');

    theTA.Comparison_Value__c = '1000';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theTA.Account_field__c = 'Account_FTE__c';
    theTA.Operator__c = 'LESS';
    theTA.Validate__c = true;
    theTA.Comparison_Value__c = '300';
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'We expect match');

    theTA.Comparison_Value__c = '100';
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theTA.Account_field__c = 'Account_FTE__c';
    theTA.Operator__c = 'BETWEEN';
    theTA.Comparison_Value__c = '100;300';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'We expect match');

    theTA.Comparison_Value__c = '1;3';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theTA.Account_field__c = 'Account_FTE__c';
    theTA.Operator__c = 'NOT_BETWEEN';
    theTA.Comparison_Value__c = '100;300';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theTA.Comparison_Value__c = '10;30';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'We expect match');

    theTA.Account_field__c = 'Org_Type__c';
    theTA.Operator__c = 'STARTS_WITH';
    theTA.Comparison_Value__c = 'Corp';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'We expect match');

    theTA.Comparison_Value__c = 'XXXX';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theTA.Operator__c = 'END_WITH';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theTA.Comparison_Value__c = 'ate';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'We expect match');

    theTA.Operator__c = 'CONTAINS';
    theTA.Validate__c = true;
    theTA.Comparison_Value__c = 'rpo';
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'We expect match');

    theTA.Validate__c = true;
    theTA.Comparison_Value__c = 'yyy';
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theTA.Operator__c = 'NOT_CONTAINS';
    theTA.Validate__c = true;
    theTA.Comparison_Value__c = 'rpo';
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'We do not expect match');

    theTA.Validate__c = true;
    theTA.Comparison_Value__c = 'yyy';
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'We expect match');

    List<Account> accs = new List<Account>();
    accs.add(theA2M); //just tto add coverage and test almost empty constructor.
    AccountTerrNameBuilderQueueable aTNQ = new AccountTerrNameBuilderQueueable(
      accs
    );
  }

  /********************************************************

********************************************************/
  @isTest
  static void testmatchingNodeWithISISNOTNULL() {
    ID allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('NODE')
      .getRecordTypeId();
    TerritoryAllocator__c theTA = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Geo__c = 'NORAM',
        Account_field__c = 'TerritoryGeo__c',
        Operator__c = 'ISNULL',
        Comparison_Value__c = 'NULL',
        RecordTypeId = allocRT
      ),
      true
    );

    Account theA2M = new Account(Name = 'TestAcc');
    //theA2M.TerritoryGeo__c = 'NORAM';
    theA2M.TerritorySegment__c = 'HIED';
    theA2M.ShippingState = 'Alabama';
    theA2M.Org_Type__c = 'Corporate';
    theA2M.Account_FTE__c = 200;

    Boolean hasMatch = AccountTerrNameBuilderQueueable.matchingNode(
      theA2M,
      theTA
    );
    System.AssertEquals(true, hasMatch, 'we expect matching territory');

    theTA.Operator__c = 'NOTNULL';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');

    theA2M.TerritorySegment__c = 'HIED';
    theA2M.ShippingState = 'Alabama';
    theA2M.Org_Type__c = 'Corporate';
    theA2M.Account_FTE__c = 200;

    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');

    theA2M.TerritoryGeo__c = 'NORAM';
    theTA.Operator__c = 'ISNULL';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');
  }

  /***************************************************
   Pass null Account field value to all Node
***************************************************/
  @isTest
  static void testmatchingNodeWithNUllValue() {
    ID allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('NODE')
      .getRecordTypeId();
    TerritoryAllocator__c theTA = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Geo__c = 'NORAM',
        Account_field__c = 'TerritoryGeo__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'NORAM',
        RecordTypeId = allocRT
      ),
      true
    );
    Account theA2M = new Account(Name = 'TestAcc');

    Boolean hasMatch = AccountTerrNameBuilderQueueable.matchingNode(
      theA2M,
      theTA
    );
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');

    theTA.Operator__c = 'NOT_EQUAL';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'we expect matching territory');

    theTA.Account_field__c = 'ShippingState';
    theTA.Operator__c = 'IN';
    theTA.Comparison_Value__c = 'Alabama,Arkansas';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');

    theTA.Account_field__c = 'ShippingState';
    theTA.Operator__c = 'IN';
    theTA.Comparison_Value__c = 'test1,Arkansas';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');

    theTA.Operator__c = 'NOT_IN';
    theTA.Comparison_Value__c = 'state1,state2';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'we expect matching territory');

    theTA.Operator__c = 'NOT_IN';
    theTA.Comparison_Value__c = 'Alabama,state2';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(true, hasMatch, 'we expect matching territory');

    theTA.Account_field__c = 'Account_FTE__c';
    theTA.Operator__c = 'GREATER';
    theTA.Comparison_Value__c = '10';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');

    theTA.Account_field__c = 'Account_FTE__c';
    theTA.Operator__c = 'LESS';
    theTA.Validate__c = true;
    theTA.Comparison_Value__c = '300';
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');

    theTA.Comparison_Value__c = '1;3';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');

    theTA.Account_field__c = 'Account_FTE__c';
    theTA.Operator__c = 'NOT_BETWEEN';
    theTA.Comparison_Value__c = '100;300';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');

    theTA.Operator__c = 'END_WITH';
    theTA.Validate__c = true;
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');

    theTA.Operator__c = 'CONTAINS';
    theTA.Validate__c = true;
    theTA.Comparison_Value__c = 'rpo';
    update theTA;
    hasMatch = AccountTerrNameBuilderQueueable.matchingNode(theA2M, theTA);
    System.AssertEquals(false, hasMatch, 'we do not expect matching territory');
  }

  @isTest
  static void testmatchingHUB() {
    Account theA2M = new Account(Name = 'TestAcc');
    theA2M.TerritoryGeo__c = 'NORAM';
    theA2M.TerritorySegment__c = 'HIED';
    theA2M.ShippingState = 'Alabama';
    theA2M.Org_Type__c = 'Corporate';
    theA2M.Account_FTE__c = 200;
    ID allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('HUB_BRANCH')
      .getRecordTypeId();
    TerritoryAllocator__c hub = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Geo__c = 'NORAM',
        Account_field__c = 'TerritoryGeo__c',
        Advanced_logic__c = '(HI1 OR HI2)',
        RecordTypeId = allocRT
      ),
      true
    );

    allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('HUB_ITEM')
      .getRecordTypeId();
    TerritoryAllocator__c hubI1 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'HI1',
        Geo__c = 'NORAM',
        Account_field__c = 'TerritoryGeo__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'NORAM',
        ParentAllocator__c = hub.id,
        RecordTypeId = allocRT
      ),
      true
    );
    TerritoryAllocator__c hubI2 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'HI2',
        Geo__c = 'APAC',
        Account_field__c = 'TerritoryGeo__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'APAC',
        ParentAllocator__c = hub.id,
        RecordTypeId = allocRT
      ),
      true
    );

    Boolean hasMatch = AccountTerrNameBuilderQueueable.matchingHub(theA2M, hub);
    System.AssertEquals(true, hasMatch, 'we expect matching territory');
  }

  @isTest
  static void testmatchingSplittedNode() {
    Account theA2M = new Account(Name = 'TestAcc');
    theA2M.TerritoryGeo__c = 'NORAM';
    theA2M.TerritorySegment__c = 'HIED';
    theA2M.ShippingState = 'Alabama';
    theA2M.Org_Type__c = 'Corporate';
    theA2M.Account_FTE__c = 200;
    ID allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('NODE')
      .getRecordTypeId();
    TerritoryAllocator__c theSplittedNode = new TerritoryAllocator__c(
      Geo__c = 'NORAM',
      Account_field__c = 'ShippingState',
      Operator__c = 'IN_SPLITTEDITEM',
      RecordtypeId = allocRT,
      Type__c = 'CUSTOM_SPLITTED',
      Local_SOQL__c = 'ShippingState IN ( \'item1\',\'Alabama\' )'
    );
    theSplittedNode = (TerritoryAllocator__c) TestFactory.createSObject(
      theSplittedNode,
      true
    );

    TerritoryAllocatorItem__c theSplittedItem1 = new TerritoryAllocatorItem__c();
    theSplittedItem1.Active__c = true;
    theSplittedItem1.Allocator__c = theSplittedNode.id;
    theSplittedItem1.Field__c = 'ShippingState';
    theSplittedItem1.Item_Value__c = 'item1';
    theSplittedItem1 = (TerritoryAllocatorItem__c) TestFactory.createSObject(
      theSplittedItem1,
      true
    );

    TerritoryAllocatorItem__c theSplittedItem2 = new TerritoryAllocatorItem__c();
    theSplittedItem2.Active__c = true;
    theSplittedItem2.Allocator__c = theSplittedNode.id;
    theSplittedItem2.Field__c = 'ShippingState';
    theSplittedItem2.Item_Value__c = 'Alabama';
    theSplittedItem2 = (TerritoryAllocatorItem__c) TestFactory.createSObject(
      theSplittedItem2,
      true
    );

    //theSplittedNode.validate__c = true;
    //update theSplittedNode; //update to validate
    //System.assertEquals('ShippingState IN ( \'item1\',\'Alabama\' )', theSplittedNode.Local_SOQL__c);

    Boolean hasMatch = AccountTerrNameBuilderQueueable.matchingSplittedNode(
      theA2M,
      theSplittedNode
    );
    System.AssertEquals(true, hasMatch, 'we expect matching territory');
  }

/*********************************************

*********************************************/
  @isTest
  static void testGetMatchingAccounts() {
    Account theA2M1 = new Account(Name = 'TestAcc1');
    theA2M1.TerritoryGeo__c = 'NORAM';
    theA2M1.TerritorySegment__c = 'HIED';
    theA2M1.Org_Type__c = 'Corporate';
    theA2M1.Account_FTE__c = 200;
    theA2M1 = (Account) TestFactory.createSObject(theA2M1, true);
    System.AssertEquals(
      theA2M1.TerritoryGeo__c,
      'NORAM',
      'GEO should not be overwritten'
    );

    Account theA2M2 = new Account(Name = 'TestAcc2');
    theA2M2.TerritoryGeo__c = 'NORAM';
    theA2M2.TerritorySegment__c = 'HIED';
    theA2M2.Org_Type__c = 'Corporate';
    theA2M2.Account_FTE__c = 200;
    theA2M2 = (Account) TestFactory.createSObject(theA2M2, true);
    System.AssertEquals(
      theA2M2.TerritorySegment__c,
      'HIED',
      'Segment should not be overwritten'
    );
  }

  /*******************************************
   //create 3 Accounts
   //creata 3 branches of 3  allocator type
   //run the code
*******************************************/
  @isTest
  static void testFindTerritoryName() {
    //this acc will match TERR1
    Account theA2M1 = new Account(Name = 'TestAcc1');
    theA2M1.TerritoryGeo__c = 'NORAM';
    theA2M1.TerritorySegment__c = 'HIED';
    theA2M1.Org_Type__c = 'Corporate';
    theA2M1.Account_FTE__c = 200;
    theA2M1 = (Account) TestFactory.createSObject(theA2M1, true);

    //this acc will match TERR2
    Account theA2M2 = new Account(Name = 'TestAcc2');
    theA2M2.TerritoryGeo__c = 'NORAM';
    theA2M2.TerritorySegment__c = 'K12';
    theA2M2.Org_Type__c = 'Corporate';
    theA2M2.Account_FTE__c = 200;
    theA2M2 = (Account) TestFactory.createSObject(theA2M2, true);

    //this acc will match TERR3
    Account theA2M3 = new Account(Name = 'TestAcc3');
    theA2M3.TerritoryGeo__c = 'NORAM';
    theA2M3.TerritorySegment__c = 'MM';
    theA2M3.Org_Type__c = 'Corporate';
    theA2M3.Account_FTE__c = 200;
    theA2M3 = (Account) TestFactory.createSObject(theA2M3, true);

    BuildSomeAllocators();

    TerritoryAllocator__c foundTA = AccountTerrNameBuilderQueueable.FindTerritoryName4Account(
      theA2M1,
      false
    );
    system.assertEquals(
      foundTA != null,
      true,
      'We expect to find matching allocator'
    );
    system.assertEquals(
      'TERR1',
      foundTA.Territory_Name__c,
      'We expect Accoutn Territory_Name to be populated with TERR1'
    );

    foundTA = AccountTerrNameBuilderQueueable.FindTerritoryName4Account(
      theA2M2,
      false
    );
    system.assertEquals(
      foundTA != null,
      true,
      'We expect to find matching allocator'
    );
    system.assertEquals(
      'TERR2',
      foundTA.Territory_Name__c,
      'We expect Accoutn Territory_Name to be populated with TERR2'
    );

    foundTA = AccountTerrNameBuilderQueueable.FindTerritoryName4Account(
      theA2M3,
      false
    );
    system.assertEquals(
      foundTA != null,
      true,
      'We expect to find matching allocator'
    );
    system.assertEquals(
      'TERR3',
      foundTA.Territory_Name__c,
      'We expect Accoutn Territory_Name to be populated with TERR3'
    );
  }

  /**************************************************************
   Helper class
**************************************************************/
  public static List<TerritoryAllocator__c> buildSomeAllocators() {
    List<TerritoryAllocator__c> tAs;
    /************* create a 3 Node branch for theA2M_1 ***********************************************/
    ID allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('NODE')
      .getRecordTypeId();

    TerritoryAllocator__c theTOPGEONODE1 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'TOP_GEO_NODE1',
        Geo__c = 'NORAM',
        Account_field__c = 'TerritoryGeo__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'NORAM',
        Validate__c = true,
        RecordTypeId = allocRT
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
        RecordTypeId = allocRT
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
        Territory_Name__c = 'TERR1',
        Order_of_Execution__c = 301,
        RecordTypeId = allocRT
      ),
      true
    );
    /************* create a 3 Node branch for theA2M_1 ***********************************************/

    /******************* create a branch with HUB for theA2M_2 ***************************************/
    allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('HUB_BRANCH')
      .getRecordTypeId();
    TerritoryAllocator__c hub = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'HUB',
        Geo__c = 'NORAM',
        Account_field__c = 'TerritoryGeo__c',
        Advanced_logic__c = '(HI1 AND HI2)',
        ParentAllocator__c = theTOPGEONODE1.id,
        RecordTypeId = allocRT
      ),
      true
    );

    allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('HUB_ITEM')
      .getRecordTypeId();
    TerritoryAllocator__c hubI1 = new TerritoryAllocator__c(
      Name = 'HI1',
      Geo__c = 'NORAM',
      Account_field__c = 'TerritorySegment__c',
      Operator__c = 'EQUAL',
      Comparison_Value__c = 'K12',
      RecordTypeId = allocRT
    );
    hubI1.Validate__c = true;
    hubI1.ParentAllocator__c = hub.id;
    hubI1 = (TerritoryAllocator__c) TestFactory.createSObject(hubI1, true);

    TerritoryAllocator__c hubI2 = new TerritoryAllocator__c(
      Name = 'HI2',
      Geo__c = 'NORAM',
      Account_field__c = 'Account_FTE__c',
      Operator__c = 'EQUAL',
      Comparison_Value__c = '200',
      RecordTypeId = allocRT
    );
    hubI2.Validate__c = true;
    hubI2.ParentAllocator__c = hub.id;
    hubI2 = (TerritoryAllocator__c) TestFactory.createSObject(hubI2, true);

    hub.Validate__c = true;
    update hub;
    allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('NODE')
      .getRecordTypeId();
    TerritoryAllocator__c theBOTTOMNODE2 = new TerritoryAllocator__c(
      Name = 'BOTTOM_NODE2',
      Geo__c = 'NORAM',
      Account_field__c = 'Org_Type__c',
      Operator__c = 'EQUAL',
      Comparison_Value__c = 'Corporate',
      RecordTypeId = allocRT
    );
    theBOTTOMNODE2.ParentAllocator__c = hub.id;
    theBOTTOMNODE2.isBottom__c = true;
    theBOTTOMNODE2.Validate__c = true;
    theBOTTOMNODE2.Order_of_Execution__c = 303;
    theBOTTOMNODE2.Territory_Name__c = 'TERR2';
    theBOTTOMNODE2 = (TerritoryAllocator__c) TestFactory.createSObject(
      theBOTTOMNODE2,
      true
    );
    /******************* create a branch with HUB for theA2M_2 ***************************************/

    /******************* SPLITTED NODE TERR branch for theA2M_3 **************************************/
    TerritoryAllocator__c theSEGMENTNODE3 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'SEGMENT_NODE3',
        Geo__c = 'NORAM',
        Account_field__c = 'TerritorySegment__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'MM',
        ParentAllocator__c = theTOPGEONODE1.id,
        Validate__c = true,
        RecordTypeId = allocRT
      ),
      true
    );
    TerritoryAllocator__c theSplittedNode = new TerritoryAllocator__c(
      Name = 'theSplittedNode',
      Geo__c = 'NORAM',
      Account_field__c = 'Org_Type__c',
      Operator__c = 'IN_SPLITTEDITEM',
      ParentAllocator__c = theSEGMENTNODE3.id,
      RecordtypeId = allocRT,
      Type__c = 'CUSTOM_SPLITTED',
      Local_SOQL__c = 'Org_Type__c IN (\'item1\',\'Corporate\')'
    );
    theSplittedNode = (TerritoryAllocator__c) TestFactory.createSObject(
      theSplittedNode,
      true
    );

    TerritoryAllocatorItem__c theSplittedItem1 = new TerritoryAllocatorItem__c();
    theSplittedItem1.Active__c = true;
    theSplittedItem1.Allocator__c = theSplittedNode.id;
    theSplittedItem1.Field__c = 'Org_Type__c';
    theSplittedItem1.Item_Value__c = 'item1';
    theSplittedItem1 = (TerritoryAllocatorItem__c) TestFactory.createSObject(
      theSplittedItem1,
      true
    );

    TerritoryAllocatorItem__c theSplittedItem2 = new TerritoryAllocatorItem__c();
    theSplittedItem2.Active__c = true;
    theSplittedItem2.Allocator__c = theSplittedNode.id;
    theSplittedItem2.Field__c = 'Org_Type__c';
    theSplittedItem2.Item_Value__c = 'Corporate';
    theSplittedItem2 = (TerritoryAllocatorItem__c) TestFactory.createSObject(
      theSplittedItem2,
      true
    );
    //once items created Valifater te splitted node and make it Bottom
    theSplittedNode.Territory_Name__c = 'TERR3';
    theSplittedNode.Order_of_Execution__c = 303;
    theSplittedNode.isBottom__c = true;
    theSplittedNode.Validate__c = true;

    update theSplittedNode;
    /******************* SPLITTED NODE TERR branch for theA2M_3 **************************************/

    TAs = [
      SELECT
        Name,
        RecordType.Name,
        Account_field__c,
        Operator__c,
        Comparison_Value__c,
        Local_filter__c,
        Local_SOQL__c,
        Built_SOQL__c,
        isBottom__c,
        Territory_Name__c,
        TerritoryTeam__c,
        Territory_Market__c,
        Segment__c,
        Geo__c //return these too to allow Validation
      FROM TerritoryAllocator__c
    ];
    for (TerritoryAllocator__c myTA : TAs) {
      System.Debug('CSABA the TA: ' + myTA);
    }

    return TAs;
  }

  /***********************************
   BuildMaps(String theGEO)
***********************************/
  @isTest
  static void testBuildMaps() {
    BuildSomeAllocators();
    AccountTerrNameBuilderQueueable.BuildMaps('NORAM');
    map<String, List<TerritoryAllocator__c>> mapBranch2AlocList = AccountTerrNameBuilderQueueable.mapBranch2AlocList;
    map<ID, TerritoryAllocator__c> mapAlocId2ParentAlloc = AccountTerrNameBuilderQueueable.mapAlocId2ParentAlloc;

    System.assertEquals(
      mapBranch2AlocList != null,
      true,
      'We check only if map was created  Do not care about content here'
    );
    System.assertEquals(
      mapAlocId2ParentAlloc != null,
      true,
      'We check only if map was created  Do not care about content here'
    );
  }
}