@istest
public class batchProcessAccountAlocator_Test {
  @testSetup
  static void testSetup() {
    Account theA2M = new Account(Name = 'TestAcc');
    theA2M.TerritoryGeo__c = 'NORAM';
    theA2M.TerritorySegment__c = 'K12';
    theA2M.TerritoryName__c = 'APAC CORP 1';
    theA2M.ShippingCountry = 'United States';
    theA2M.Org_Type__c = 'K12';
    theA2M.Primary_Business__c = 'K12';
    theA2M.ShippingPostalCode = '123456';
    theA2M.Need_Alignment__c = true;
    theA2M = (Account) TestFactory.createSObject(theA2M, true);
    system.assertEquals(true, theA2M.id != null, theA2M);
  }

  @isTest
  static void testbatchAllocatorExecute() {
    List<Account> accs2test = [SELECT Id FROM Account];
    system.assertEquals(
      true,
      accs2test.size() > 0,
      'we expect accounts to exist'
    );

    batchProcessAccountAlocator batchu;

    Test.startTest();

    Test.setMock(WebServiceMock.class, new AccountAllocatorCalloutMock());

    batchu = new batchProcessAccountAlocator(accs2test[0].id);
    DataBase.executeBatch(batchu);

    Test.stopTest(); //no need to do assertion here because btch call method  form other class which methods were tested
  }

  @isTest
  static void testbatchAllocatorExecuteWithException() {
    Batch_Job_Monitor__c headeru = new Batch_Job_Monitor__c();
    headeru.BatchClassName__c = 'batchProcessAccountAlocator';
    headeru.Active__c = true;
    headeru.Log_Level__c = 'High';
    insert headeru;
    system.assertNotEquals(
      null,
      headeru.id,
      'Batch Job Monitor record should be created'
    );

    batchProcessAccountAlocator batchu;
    try {
      Test.startTest();
      Test.setMock(WebServiceMock.class, new AccountAllocatorCalloutMock());
      batchu = new batchProcessAccountAlocator(-1);
      DataBase.executeBatch(batchu);

      Test.stopTest();
    } catch (Exception myEx) {
      System.assert(
        true,
        'We do not want to handle catch. We do assert below for bjmis'
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
      'Bath Job Monitor Item should exist due to the exceptin we generated'
    );
  }

  @isTest
  static void testcheckAlignmentProcess() {
    //add code here because no Callout to align.
    Account thea = [SELECT ID, TerritoryName__c FROM Account LIMIT 1];
    Territory2 t2t = [
      SELECT ID, Name
      FROM Territory2
      WHERE Name = 'APAC CORP 1'
    ];

    ObjectTerritory2Association ota = new ObjectTerritory2Association(
      ObjectId = thea.id,
      Territory2Id = t2t.Id,
      AssociationCause = 'Territory2Manual'
    );
    insert ota;
    batchProcessAccountAlocator ab = new batchProcessAccountAlocator(1);
    batchProcessAccountAlocator.AlocationResult alocres = AccountTerrAlocatorQueueable.checkAlignmentProcess(
      new Set<ID>{ thea.Id }
    );

    System.assertEquals(
      1,
      alocres.success,
      'We expect 1 succsefull allocation result'
    );
    System.assertEquals(0, alocres.failure, 'we expect 0 allocation failure');
  }

  @isTest
  static void testCreateBMJ() {
    Batch_Job_Monitor__c headeru = new Batch_Job_Monitor__c();
    headeru.BatchClassName__c = 'batchu';
    headeru.Active__c = true;
    insert headeru;
    system.assertNotEquals(
      null,
      headeru.id,
      'We expect 1 Batch Job monitor record'
    );

    Batch_Job_Monitor__c workeru = batchProcessAccountAlocator.createBatchMonitor(
      headeru.id,
      'batchu',
      1,
      0,
      'comment'
    );
    system.assertNotEquals(
      null,
      workeru.id,
      'We expect 1 BJM record to be creaetd by the method createBatchMonitor'
    );

    List<Batch_Job_Monitor__c> bjms = [
      SELECT id, nrofSuccess__c, NrofFailures__c
      FROM Batch_Job_Monitor__c
      WHERE Parent_BatchMonitor__c = :headeru.id
    ];
    System.assertEquals(1, BJMs.size(), '1 BJM should exist');
    System.assertEquals(
      1,
      BJMs[0].nrofSuccess__c,
      'BJM should contain 1  success'
    );
    System.assertEquals(
      0,
      BJMs[0].NrofFailures__c,
      'BJM should contain 0 failure'
    );

    //add code to test Create BJMItem
    Batch_Job_Monitor_Item__c bjmi = batchProcessAccountAlocator.createBatchMonitorItem(
      BJMs[0].id,
      'String themsg',
      'String thePhase',
      'String item'
    );
    System.assertEquals(
      bjmi.Parent_Job_Monitor__c,
      BJMs[0].id,
      'bjmItem should be linked to parent BJM'
    );
    System.assertEquals(
      bjmi.Message__c,
      'String themsg',
      'Just check if parameter msf went through'
    );
    System.assertEquals(
      bjmi.Error_Phase__c,
      'String thePhase',
      'Just check if parameter ErrorPhase went through'
    );
    System.assertEquals(
      bjmi.Affected_record__c,
      'String item',
      'Just chekc if parameter AffecterRecord went through'
    );
  }
}