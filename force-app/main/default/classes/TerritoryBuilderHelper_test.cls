@isTest
public class TerritoryBuilderHelper_test {
  @testSetup
  static void testSetup() {
    TestFactory.createSObject(
      new TerritoryAllocator__c(
        Geo__c = 'NORAM',
        Account_field__c = 'TerritoryGeo__c',
        Operator__c = 'EQUAL'
      ),
      true
    );
  }

  @isTest
  static void testCreateSplitAllocator() {
    ID allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('NODE')
      .getRecordTypeId();
    TerritoryAllocator__c theSplittedNode = new TerritoryAllocator__c(
      Geo__c = 'NORAM',
      Account_field__c = 'ShippingPostalCode4Terr__c',
      Operator__c = 'IN_SPLITTEDITEM',
      Type__c = 'CUSTOM_SPLITTED'
    );
    theSplittedNode.RecordtypeId = allocRT;
    theSplittedNode = (TerritoryAllocator__c) TestFactory.createSObject(
      theSplittedNode,
      true
    );

    TerritoryAllocatorItem__c theSplittedItem1 = new TerritoryAllocatorItem__c();
    theSplittedItem1.Active__c = true;
    theSplittedItem1.Allocator__c = theSplittedNode.id;
    theSplittedItem1.Field__c = 'ShippingPostalCode4Terr__c';
    theSplittedItem1.Item_Value__c = 'item1';
    theSplittedItem1 = (TerritoryAllocatorItem__c) TestFactory.createSObject(
      theSplittedItem1,
      true
    );

    TerritoryAllocatorItem__c theSplittedItem2 = new TerritoryAllocatorItem__c();
    theSplittedItem2.Active__c = true;
    theSplittedItem2.Allocator__c = theSplittedNode.id;
    theSplittedItem2.Field__c = 'ShippingPostalCode4Terr__c';
    theSplittedItem2.Item_Value__c = 'item2';
    theSplittedItem2 = (TerritoryAllocatorItem__c) TestFactory.createSObject(
      theSplittedItem2,
      true
    );

    TerritoryBuilderHelper.CreateSplitAllocator(theSplittedNode);
    String expected = 'ShippingPostalCode4Terr__c IN ( \'item1\',\'item2\' )';
    String actual = theSplittedNode.Built_SOQL__c;
    System.AssertEquals(expected, actual, 'Expect Allocator BuildSQL to match');
  }

  /****************************************

****************************************/
  @isTest
  static void testBuildHUBquery() {
    TerritoryAllocator__c theHUB = new TerritoryAllocator__c(
      Geo__c = 'NORAM',
      Account_field__c = 'TerritoryGeo__c',
      Advanced_logic__c = '(HI1 AND HI2)'
    );
    ID allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('HUB_BRANCH')
      .getRecordTypeId();
    theHUB.RecordtypeId = allocRT; //'012S0000000ZyRi';  //DO NOT HARDCODE
    theHUB = (TerritoryAllocator__c) TestFactory.createSObject(theHUB, true);

    List<TerritoryBuilderHelper.SQLBuilderWrapper> params = new List<TerritoryBuilderHelper.SQLBuilderWrapper>();
    TerritoryBuilderHelper.SQLBuilderWrapper bw = new TerritoryBuilderHelper.SQLBuilderWrapper();

    bw.currentRecord = theHUB;
    params.add(bw);

    allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('HUB_ITEM')
      .getRecordTypeId();
    TerritoryAllocator__c theTA1 = new TerritoryAllocator__c(
      Name = 'HI1',
      Geo__c = 'NORAM',
      Account_field__c = 'TerritoryGeo__c',
      Operator__c = 'EQUAL',
      Comparison_Value__c = 'NORAM',
      ParentAllocator__c = theHUB.id,
      Local_filter__c = 'TerritoryGeo__c = \'NORAM\''
    );
    theTA1.RecordtypeId = allocRT;
    theTA1 = (TerritoryAllocator__c) TestFactory.createSObject(theTA1, true);
    TerritoryAllocator__c theTA2 = new TerritoryAllocator__c(
      Name = 'HI2',
      Geo__c = 'NORAM',
      Account_field__c = 'Institution_FTE__c',
      Operator__c = 'LESS',
      Comparison_Value__c = '100',
      ParentAllocator__c = theHUB.id,
      Local_filter__c = 'Institution_FTE__c < 100'
    );
    theTA2.RecordtypeId = allocRT; //'012S0000000ZyW0'; //DO NOT HARDCODE
    theTA2 = (TerritoryAllocator__c) TestFactory.createSObject(theTA2, true);

    String expected = '(TerritoryGeo__c = \'NORAM\' AND Institution_FTE__c < 100)';
    List<String> retval = TerritoryBuilderHelper.buildHUBquery(params);
    System.assertEquals(1, retval.size(), 'Expect to have 1 Build SQL item');
    System.AssertEquals(
      expected,
      retval[0],
      'Expect Allocator BuildSQL to match'
    );
  }

  /**************************************
   String ValidateSOQL(String Whereclause)
**************************************/
  @isTest
  static void testValidateSOQL() {
    String thewhere = 'Name = \'noname\' ';
    String retval = TerritoryBuilderHelper.ValidateSOQL(theWhere);
    System.AssertEquals(
      retval.startswith('VALID'),
      true,
      'Expect Build SQL to be a valid SOQL'
    );

    thewhere = 'Namu = \'noname\' ';
    retval = TerritoryBuilderHelper.ValidateSOQL(theWhere);
    System.AssertEquals(
      retval.startswith('No such column '),
      true,
      'the return ed SOQL exception should point to non0existing Accout field'
    );
  }

  /***********************************

***********************************/
  @isTest
  static void testMakeQuery() {
    String field = 'TerritoryGeo__c';
    String op = 'EQUAL';
    String valu = 'APAC';

    String expected = '( TerritoryGeo__c = \'' + valu + '\' )';
    String retval = TerritoryBuilderHelper.MakeSOQL(field, op, valu);
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );
  }
  /****************************************
   pass String filed  and Numeric
   pass ULL val  and not null
****************************************/
  @isTest
  static void testEQUALNOTEQUAL() {
    String field = 'TerritoryGeo__c';
    String valu = 'APAC';
    String fType = 'STRING';

    String expected = '( TerritoryGeo__c = \'' + valu + '\' )';
    String retval = TerritoryBuilderHelper.BuildEqualSOQL(
      field,
      valu,
      ftype,
      false
    );
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );

    expected = '( TerritoryGeo__c != \'' + valu + '\' )';
    retval = TerritoryBuilderHelper.BuildEqualSOQL(field, valu, ftype, true);
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );

    field = 'Employee_Count__c';
    valu = '10';
    fType = 'NUMERIC';

    expected = '( Employee_Count__c != ' + valu + ' )';
    retval = TerritoryBuilderHelper.BuildEqualSOQL(field, valu, ftype, true);
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );

    valu = null;

    expected = '( Employee_Count__c = null )';
    retval = TerritoryBuilderHelper.BuildEqualSOQL(field, valu, ftype, false);
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );
  }

  /**********************************

**********************************/
  @isTest
  static void testGRELESS() {
    String field = 'Employee_Count__c';
    String valu = '10';
    String expected = '( Employee_Count__c > ' + valu + ' )';
    String retval = TerritoryBuilderHelper.Build_GRELESS_SOQL(
      field,
      valu,
      true
    );
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );

    expected = '( Employee_Count__c < ' + valu + ' )';
    retval = TerritoryBuilderHelper.Build_GRELESS_SOQL(field, valu, false);
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );
  }

  /*********************************

*********************************/
  @isTest
  static void testBETWEEN() {
    String field = 'Employee_Count__c';
    String valu = '10;20';
    String expected = '( Employee_Count__c > 10 AND Employee_Count__c < 20 )';
    String retval = TerritoryBuilderHelper.Build_BETWEEN_SOQL(
      field,
      valu,
      false
    );
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );

    expected = '( Employee_Count__c < 10 AND Employee_Count__c > 20 )';
    retval = TerritoryBuilderHelper.Build_BETWEEN_SOQL(field, valu, true);
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );
  }

  /**********************************

**********************************/
  @isTest
  static void testINNOTIN() {
    String field = 'TerritoryGeo__c';
    String valu = 'T1,T2';
    String expected = 'TerritoryGeo__c IN ( \'T1\',\'T2\' )';
    String retval = TerritoryBuilderHelper.Build_IN_SOQL(field, valu, false);
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );

    expected = '( NOT TerritoryGeo__c IN ( \'T1\',\'T2\' ) )';
    retval = TerritoryBuilderHelper.Build_IN_SOQL(field, valu, true);
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );
  }

  /********************************
   Build_ISNULL_SOQL(String field)
********************************/
  @isTest
  static void testISNULL() {
    String field = 'TerritoryGeo__c';
    String expected = '( TerritoryGeo__c = NULL )';
    String retval = TerritoryBuilderHelper.Build_IS_NOT_NULL_SOQL(field, '=');
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );

    expected = '( TerritoryGeo__c != NULL )';
    retval = TerritoryBuilderHelper.Build_IS_NOT_NULL_SOQL(field, '!=');
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );
  }

  /******************************

******************************/
  @isTest
  static void testLIKE() {
    String field = 'TerritoryGeo__c';
    String valu = 'AP';
    String expected = '( TerritoryGeo__c Like \'AP%\' )';
    String retval = TerritoryBuilderHelper.Build_LIKE_SOQL(
      field,
      valu,
      'STARTS_WITH'
    );

    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );

    expected = '( TerritoryGeo__c Like \'%AP\' )';
    retval = TerritoryBuilderHelper.Build_LIKE_SOQL(field, valu, 'END_WITH');
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );

    expected = '( TerritoryGeo__c Like \'%AP%\' )';
    retval = TerritoryBuilderHelper.Build_LIKE_SOQL(field, valu, 'CONTAINS');
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );

    expected = '( NOT TerritoryGeo__c Like \'%AP%\' )';
    retval = TerritoryBuilderHelper.Build_LIKE_SOQL(
      field,
      valu,
      'NOT_CONTAINS'
    );
    System.AssertEquals(
      expected,
      retval,
      'Expect Build SQL to match the field/op/value'
    );
  }

  @isTest
  static void testPlayWihtPropagate() {
    //creater 1 TA and play with different field to increase coverage
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

    //clear the bottom node  BuildQuery then try  to set forcePropagate for the top
    theBOTTOMNODE1 = [
      SELECT Built_SOQL__c
      FROM TerritoryAllocator__c
      WHERE id = :theBOTTOMNODE1.id
    ];
    String theBQ = theBOTTOMNODE1.Built_SOQL__c;
    theBOTTOMNODE1.Built_SOQL__c = null;
    update theBOTTOMNODE1;

    theTOPGEONODE1.Validate__c = true;
    update theTOPGEONODE1;

    theBOTTOMNODE1 = [
      SELECT Built_SOQL__c
      FROM TerritoryAllocator__c
      WHERE id = :theBOTTOMNODE1.id
    ];
    System.AssertEquals(
      theBQ,
      theBOTTOMNODE1.Built_SOQL__c,
      'Update should re-create the Node  Biuld SQL field'
    );
  }

  @istest
  static void playWithCustomSplitted() {
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
      ParentAllocator__c = theSEGMENTNODE1.id,
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
    //once items created Validater te splitted node and make it Bottom
    theSplittedNode.Territory_Name__c = 'TERR3';
    theSplittedNode.Order_of_Execution__c = 303;
    theSplittedNode.isBottom__c = true;
    theSplittedNode.Validate__c = true;

    update theSplittedNode;

    String expected = '( TerritoryGeo__c = \'NORAM\' ) AND ( TerritorySegment__c = \'MM\' ) AND Org_Type__c IN ( \'Corporate\',\'item1\' )';
    theSplittedNode = [
      SELECT id, Built_SOQL__c
      FROM TerritoryAllocator__c
      WHERE id = :theSplittedNode.id
    ];
    String expectedBQ = theSplittedNode.Built_SOQL__c;
    System.AssertEquals(
      ExpectedBQ,
      expected,
      'Expect to pull filter condition from the HUB\'s Items'
    );

    //clear the theSplittedNode Build_SQL and Validate Top Node
    theSplittedNode.Built_SOQL__c = null;
    update theSplittedNode;

    theTOPGEONODE1.Validate__c = true;
    update theTOPGEONODE1;
    theSplittedNode = [
      SELECT id, Built_SOQL__c
      FROM TerritoryAllocator__c
      WHERE id = :theSplittedNode.id
    ];
    System.AssertEquals(
      ExpectedBQ,
      theSplittedNode.Built_SOQL__c,
      'if parent node is re-validated child nodes should re-calculate'
    );
  }

  @isTest
  static void testvalidateMarketSegment() {
    List<TerritoryAllocator__c> tAs = new List<TerritoryAllocator__c>();

    ID allocRT = Schema.SObjectType.TerritoryAllocator__c.getRecordTypeInfosByDeveloperName()
      .get('NODE')
      .getRecordTypeId();

    //create several bottom territoties  according to  configuration in  method TerritoryBuilderHelper.setTerrMarket
    TerritoryAllocator__c theTA1 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'BOTTOM_NODE1',
        Geo__c = 'NORAM',
        Account_field__c = 'Org_Type__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'Corporate',
        Validate__c = true,
        isBottom__c = true,
        Territory_Name__c = 'NORAM CORP ENT',
        Order_of_Execution__c = 301,
        RecordTypeId = allocRT
      ),
      true
    );
    TerritoryAllocator__c tA2 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'BOTTOM_NODE2',
        Geo__c = 'LATAM',
        Account_field__c = 'Org_Type__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'Corporate',
        Validate__c = true,
        isBottom__c = true,
        Territory_Name__c = 'LATAM_TERR',
        Order_of_Execution__c = 201,
        RecordTypeId = allocRT
      ),
      true
    );
    TerritoryAllocator__c tA3 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'BOTTOM_NODE3',
        Geo__c = 'APAC',
        Account_field__c = 'Org_Type__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'Corporate',
        Validate__c = true,
        isBottom__c = true,
        Territory_Name__c = 'APAC CORP',
        Order_of_Execution__c = 101,
        RecordTypeId = allocRT
      ),
      true
    );

    TerritoryAllocator__c tA4 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'BOTTOM_NODE4',
        Geo__c = 'NORAM',
        Account_field__c = 'Org_Type__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'Corporate',
        Validate__c = true,
        isBottom__c = true,
        Territory_Name__c = 'NORAM HIED',
        Order_of_Execution__c = 304,
        RecordTypeId = allocRT
      ),
      true
    );
    TerritoryAllocator__c tA5 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'BOTTOM_NODE5',
        Geo__c = 'NORAM',
        Account_field__c = 'Org_Type__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'Corporate',
        Validate__c = true,
        isBottom__c = true,
        Territory_Name__c = 'NORAM K12',
        Order_of_Execution__c = 305,
        RecordTypeId = allocRT
      ),
      true
    );
    TerritoryAllocator__c tA6 = (TerritoryAllocator__c) TestFactory.createSObject(
      new TerritoryAllocator__c(
        Name = 'BOTTOM_NODE6',
        Geo__c = 'NORAM',
        Account_field__c = 'Org_Type__c',
        Operator__c = 'EQUAL',
        Comparison_Value__c = 'Corporate',
        Validate__c = true,
        isBottom__c = true,
        Territory_Name__c = 'NORAM Enterprise',
        Order_of_Execution__c = 306,
        RecordTypeId = allocRT
      ),
      true
    );

    TAs.add(theTA1);
    TAs.add(tA2);
    TAs.add(tA3);
    TAs.add(tA4);
    TAs.add(tA5);
    TAs.add(tA6);

    TAs = [
      SELECT
        Name,
        isBottom__c,
        Territory_Name__c,
        TerritoryTeam__c,
        Territory_Market__c,
        Segment__c,
        Geo__c
      FROM TerritoryAllocator__c
    ];

    ValidateTerritoryMarket(TAs);
    ValidateTerritorySegment(TAs);

    System.assert(
      true,
      'Hello PDM. the asserts are in the above 2 methods so do not complain.'
    );
  }

  /*********************************************************************************
  this is not a test method. It  is called from test methods and we do assert here.
  *********************************************************************************/
  public static void validateTerritoryMarket(
    List<TerritoryAllocator__c> theTAs
  ) {
    String market2Match;
    for (TerritoryAllocator__c theTA : theTAs) {
      if (theTA.isBottom__c == false) {
        continue;
      }

      if (theTA.Geo__c == 'LATAM') {
        market2Match = 'EDU';
      }

      if (
        theTA.Geo__c == 'APAC' &&
        (theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('CORP') ||
        (theTA.TerritoryTeam__c != null &&
        theTA.TerritoryTeam__c.contains('CORP')))
      ) {
        market2Match = 'CORP';
      }

      if (
        (theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('HIED')) ||
        (theTA.TerritoryTeam__c != null &&
        theTA.TerritoryTeam__c.contains('HIED'))
      ) {
        Market2Match = 'EDU';
      }

      if (
        (theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('K12')) ||
        (theTA.TerritoryTeam__c != null &&
        theTA.TerritoryTeam__c.contains('K12'))
      ) {
        Market2Match = 'EDU';
      }

      if (
        theTA.Geo__c == 'NORAM' &&
        ((theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('Enterprise')) ||
        (theTA.TerritoryTeam__c != null &&
        theTA.TerritoryTeam__c.contains('ENT')))
      ) {
        Market2Match = 'CORP';
      }

      if (
        theTA.Geo__c == 'NORAM' &&
        (theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('NORAM CORP ENT')) ||
        (theTA.TerritoryTeam__c != null &&
        (theTA.TerritoryTeam__c.contains('SME') ||
        theTA.TerritoryTeam__c.contains('MM')))
      ) {
        Market2Match = 'CORP';
      }

      if (
        (theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('RTO')) ||
        (theTA.TerritoryTeam__c != null &&
        theTA.TerritoryTeam__c.contains('RTO'))
      ) {
        Market2Match = 'EDU';
      }

      if (
        theTA.TerritoryTeam__c != null &&
        (theTA.TerritoryTeam__c == 'EMEA EDU ENT' ||
        theTA.TerritoryTeam__c == 'EMEA EDU MM UK' ||
        theTA.TerritoryTeam__c == 'EMEA EDU MM EMERG' ||
        theTA.TerritoryTeam__c == 'EMEA EDU MM BENONORD' ||
        theTA.TerritoryTeam__c == 'EMEA EDU INSIDE')
      ) {
        Market2Match = 'EDU';
      }

      if (
        theTA.TerritoryTeam__c != null &&
        (theTA.TerritoryTeam__c == 'EMEA CORP ENT 1' ||
        theTA.TerritoryTeam__c == 'EMEA CORP MM' ||
        theTA.TerritoryTeam__c == 'EMEA CORP ENT 2' ||
        theTA.TerritoryTeam__c == 'EMEA CORP IS')
      ) {
        Market2Match = 'CORP';
      }

      System.assertNotEquals(
        Market2Match,
        null,
        'Accoutn MArket value shuld not be NULL'
      );
      System.assertEquals(Market2Match, theTA.territory_Market__c, theTA);
    }
  }

  /********************************************************************************
  this is not a test method. It  is called from test methods and we do assert here.
  ********************************************************************************/
  public static void validateTerritorySegment(
    List<TerritoryAllocator__c> theTAs
  ) {
    String segment2Match;
    for (TerritoryAllocator__c theTA : theTAs) {
      if (theTA.isBottom__c == false) {
        continue; //do this only for Bottom
      }

      if (theTA.Geo__c == 'LATAM') {
        segment2Match = 'HIED';
        System.assertEquals(Segment2Match, theTA.Segment__c, theTA);
        continue;
      }

      if (
        theTA.Geo__c == 'APAC' &&
        ((theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('CORP')) ||
        (theTA.TerritoryTeam__c != null &&
        theTA.TerritoryTeam__c.contains('CORP')))
      ) {
        Segment2Match = 'CORP';
        System.assertEquals(Segment2Match, theTA.Segment__c, theTA);
        continue;
      }

      if (
        theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('HIED') ||
        theTA.TerritoryTeam__c != null &&
        theTA.TerritoryTeam__c.contains('HIED')
      ) {
        Segment2Match = 'HIED';
        System.assertEquals(Segment2Match, theTA.Segment__c, theTA);
        continue;
      }

      if (
        theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('K12') ||
        theTA.TerritoryTeam__c != null && theTA.TerritoryTeam__c.contains('K12')
      ) {
        Segment2Match = 'K12';
        System.assertEquals(Segment2Match, theTA.Segment__c, theTA);
        continue;
      }

      if (
        theTA.Geo__c == 'NORAM' &&
        ((theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('Enterprise')) ||
        (theTA.TerritoryTeam__c != null &&
        theTA.TerritoryTeam__c.contains('ENT')))
      ) {
        Segment2Match = 'ENT';
        System.assertEquals(Segment2Match, theTA.Segment__c, theTA);
        continue;
      }

      if (
        theTA.Geo__c == 'NORAM' &&
        (theTA.TerritoryTeam__c != null &&
        (theTA.TerritoryTeam__c.contains('MM') ||
        theTA.TerritoryTeam__c.contains('SME')))
      ) {
        Segment2Match = 'MM';
        System.assertEquals(Segment2Match, theTA.Segment__c, theTA);
        continue;
      }

      if (
        theTA.Geo__c == 'NORAM' &&
        theTA.TerritoryTeam__c != null &&
        theTA.TerritoryTeam__c.contains('NORAM CORP ENT')
      ) {
        Segment2Match = 'ENT';
        System.assertEquals(Segment2Match, theTA.Segment__c, theTA);
        continue;
      }

      if (
        (theTA.territory_Name__c != null &&
        theTA.territory_Name__c.contains('RTO')) ||
        (theTA.TerritoryTeam__c != null &&
        theTA.TerritoryTeam__c.contains('RTO'))
      ) {
        Segment2Match = 'RTO';
        System.assertEquals(Segment2Match, theTA.Segment__c, theTA);
        continue;
      }

      //INCLUDE EMEA rule here too
      if (theTA.TerritoryTeam__c == 'EMEA EDU ENT') {
        Segment2Match = 'ENT';
      }
      if (
        theTA.TerritoryTeam__c == 'EMEA EDU MM UK' ||
        theTA.TerritoryTeam__c == 'EMEA EDU MM BENONORD' ||
        theTA.TerritoryTeam__c == 'EMEA EDU MM EMERG' ||
        theTA.TerritoryTeam__c == 'EMEA EDU INSIDE'
      ) {
        Segment2Match = 'MM';
      }
      if (
        theTA.TerritoryTeam__c == 'EMEA CORP ENT 1' ||
        theTA.TerritoryTeam__c == 'EMEA CORP MM'
      ) {
        Segment2Match = 'ENT 1';
      }
      if (theTA.TerritoryTeam__c == 'EMEA CORP ENT 2') {
        Segment2Match = 'ENT 2';
      }
      if (theTA.TerritoryTeam__c == 'EMEA CORP IS') {
        Segment2Match = 'IS';
      }

      System.assertEquals(Segment2Match, theTA.Segment__c, theTA);
      continue;
    }
  }
}