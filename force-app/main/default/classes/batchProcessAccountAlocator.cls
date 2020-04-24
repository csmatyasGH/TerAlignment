/**************************************************************************************************************************
   Class Aloocate  Account by  callign a SOAP API Update call
**************************************************************************************************************************/
global class batchProcessAccountAlocator implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts, Database.RaisesPlatformEvents {
  Id account2Align;

  global integer totalSucess = 0;
  global integer totalFailure = 0;

  public integer nrofAccount;

  /************** used only during tests  ***********/
  public batchProcessAccountAlocator(integer thelimit) {
    nrofAccount = thelimit;
  }

/*****************************************
used for 1 Account alignment and TestClass
*****************************************/
  public batchProcessAccountAlocator(ID aID) {
    Account2Align = aID;
  }

  global Database.QueryLocator start(Database.BatchableContext theBC) {
    //AccountTerritoryNameBuilder.
    CreateBatchMonitor(
      theBC.getJobId(),
      'batchProcessAccountAlocator',
      0,
      0,
      'Alignment'
    );

    String query;
    query = 'Select ID, Name,Name4Terr__c, TerritoryName__c,TerritoryName_Suggested__c,ShippingPostalCode ,ShippingPostalCode4Terr__c';
    query = query + ' from Account where Need_Alignment__c = true ';

    if (Account2Align != null) {
      query = query + ' AND ID = \'' + Account2Align + '\'';
    }

    if (nrofAccount == null) {
      query = query + ' limit 500000';
    } else {
      query = query + 'limit ' + nrofAccount;
    }

    return Database.getQueryLocator(query);
  }

  /*********************************************************************
   collect all AccountId  and call SOAP API. Check the alocation results.
*********************************************************************/
  global void execute(Database.BatchableContext theBC, List<sObject> scope) {
    Set<Id> sA2A = new Set<ID>();

    for (Account theA : (List<Account>) scope) {
      sA2A.add(theA.id);
    }

    List<partnerSoapSforceCom.SaveResult> sr = AccountTerrAlocatorQueueable.AllignAccountSoap(
      sA2A
    );
    //2019.11.08. replaced with below. AlocationResult alocRes = checkAlignmentProcess(sA2A);
    AlocationResult alocRes = AccountTerrAlocatorQueueable.checkAlignmentProcess(
      sA2A
    );
    totalSucess = totalSucess + alocRes.Success;
    totalFailure = totalFailure + alocRes.Failure;
  }

  global void finish(Database.BatchableContext theBC) {
    //AccountTerritoryNameBuilder.
    CreateBatchMonitor(
      theBC.getJobId(),
      'batchProcessAccountAlocator',
      totalSucess,
      totalFailure,
      'Alignment'
    );
  }

  /************************ the below 2 methods are helper methods for batch monitoring useb by both batc classes *******************************/

  /***********************************************************************************************************************************************
In case we have an active Parent BJM for this class create a worker BJM.
***********************************************************************************************************************************************/
  public static Batch_Job_Monitor__c createBatchMonitor(
    Id batchJobID,
    String batchClassName,
    Integer success,
    Integer failure,
    String theComment
  ) {
    List<Batch_Job_Monitor__c> parentBJMs = [
      SELECT Id, Log_Level__c
      FROM Batch_Job_Monitor__c
      WHERE
        BatchClassName__c = :BatchClassName
        AND Parent_BatchMonitor__c = null
        AND Active__c = true
      LIMIT 1
    ];

    if (parentBJMs.size() == 0) {
      return null;
    }

    Batch_Job_Monitor__c thenewBJM = new Batch_Job_Monitor__c(
      Parent_BatchMonitor__c = parentBJMs[0].id,
      BatchClassName__c = batchClassName
    );
    thenewBJM.comment__c = theComment;
    thenewBJM.BatchJobID__c = batchJobID;
    thenewBJM.nrofSuccess__c = success;
    thenewBJM.NrofFailures__c = failure;
    //insert thenewBJM;
    Database.upsertresult durs = Database.upsert(
      thenewBJM,
      Batch_Job_Monitor__c.BatchJobID__c,
      false
    );
    thenewBJM.comment__c = parentBJMs[0].Log_Level__c; //just to pass the loglevel back to caller
    return thenewBJM;
  }

  /********************************************************************************************************************
will bwe called from BatchApexErrorEvents_Trigger
********************************************************************************************************************/
  public static Batch_Job_Monitor_Item__c createBatchMonitorItem(
    ID bjmID,
    String themsg,
    String thePhase,
    String item
  ) {
    Batch_Job_Monitor_Item__c bjmi = new Batch_Job_Monitor_Item__c();
    bjmi.Parent_Job_Monitor__c = bjmID;
    bjmi.Message__c = themsg;
    bjmi.Error_Phase__c = thePhase;
    bjmi.Affected_record__c = item;

    return bjmi;
  }

  public class AlocationResult {
    public integer success;
    public integer failure;

    public AlocationResult() {
      success = 0;
      failure = 0;
    }

    public AlocationResult(integer s, integer f) {
      success = s;
      failure = f;
    }
  }
}