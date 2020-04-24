public without sharing class batchPlatformEvErrorTriggerXHandler extends TriggerX {
  public batchPlatformEvErrorTriggerXHandler() {
  }

  public override void onAfterInsert() {
    //hopefully 1 insert  will came from the same Apex
    Set<Id> asyncApexJobIds = new Set<Id>();
    for (BatchApexErrorEvent evt : (List<BatchApexErrorEvent>) records) {
      asyncApexJobIds.add(evt.AsyncApexJobId);
    }

    map<ID, ID> mapBJId2BJMID = new Map<ID, ID>();
    Set<ID> batchJobId = new Set<ID>();
    List<Batch_Job_Monitor__C> bjms = [
      SELECT
        id,
        BatchJobID__c,
        BatchClassName__c,
        Parent_BatchMonitor__r.Active__c,
        Parent_BatchMonitor__r.Log_Level__c
      FROM Batch_Job_Monitor__C
      WHERE
        BatchJobID__c IN :asyncApexJobIds
        AND Parent_BatchMonitor__r.Log_Level__c = 'High'
    ];
    if (bjms.size() == 0) {
      return;
    }

    for (Batch_Job_Monitor__C bjm : bjms) {
      batchJobId.add(bjm.BatchJobID__c);
      mapBJId2BJMID.put(bjm.BatchJobID__c, bjm.Id);
    }
    List<Batch_Job_Monitor_Item__c> bjmis = new List<Batch_Job_Monitor_Item__c>();
    for (BatchApexErrorEvent evt : (List<BatchApexErrorEvent>) records) {
      //only handle events for the job(s) we care about
      if (mapBJId2BJMID.keyset().contains(evt.AsyncApexJobId)) {
        ID bjmID = mapBJId2BJMID.get(evt.AsyncApexJobId);

        if (evt.JobScope == null) {
          Batch_Job_Monitor_Item__c bjmiNE = batchProcessAccountAlocator.createBatchMonitorItem(
            bjmID,
            evt.Message,
            evt.Phase,
            'No record'
          );
          BJMIs.add(bjmiNE);
          continue;
        }

        for (String item : evt.JobScope.split(',')) {
          //try to create here a BJM_Item records based on ect fields
          Batch_Job_Monitor_Item__c bjmi = batchProcessAccountAlocator.createBatchMonitorItem(
            bjmID,
            evt.Message,
            evt.Phase,
            item
          );
          BJMIs.add(bjmi);
        }
      }
    }

    if (BJMIs.size() > 0) {
      Database.insert(BJMIs, false);
    }
  }
}