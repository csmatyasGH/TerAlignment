/***************************************************
 this class is intended to support Batch Job Monitor
 to store statistics and error from bach job run.
 **************************************************/
public without sharing class batchJobMonitorUtility 
{

    /************************************************************************
    shoud be called from bach class Start method if we want BJM for the batch 
    ************************************************************************/
    public static void attachBJM2Class(ID bcId, Batch_Job_Monitor__c theBJM)
    {
      theBJM = CreateBatchMonitor(
        bcId,
        'batchSyncOrphanOpps',
        0,
        0,
        'Sync oprhan Opps'
      );
    }  

    /*****************************************************
    first check if the batch class has parent BJM record.
    if not return, if yet create the child BJM. 
    It can be called for Update too because we use upsert
    *****************************************************/
    public static Batch_Job_Monitor__c createBatchMonitor(
        Id batchJobID,
        String batchClassName,
        Integer success,
        Integer failure,
        String theComment
      ) {
        //get the parent of exists.
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

        Database.upsertresult durs = Database.upsert(
          thenewBJM,
          Batch_Job_Monitor__c.BatchJobID__c,
          false
        );
        thenewBJM.comment__c = parentBJMs[0].Log_Level__c; //just to pass the loglevel back to caller
        return thenewBJM;
      }
    
         /**************************************************************
         * 
         **************************************************************/
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
        
    /**************************************************************************************
    iterate through SaveResult and in case of error write to BatchJob_MonitorItem or if the
    parameter2 is NULL just display a debug msg. 
    **************************************************************************************/
    public static integer processDBSaveResults(List<Database.SaveResult> drsrs, ID bjmID) {
      integer retval = 0;
      List<Batch_Job_Monitor_Item__c> bjmis = new List<Batch_Job_Monitor_Item__c>();
      for (Database.SaveResult sr : drsrs) {
        if (sr.isSuccess()) {
          retval++;
        } else {
          for (Database.Error err : sr.getErrors()) 
          { 
            String errmsg = err.getMessage();
            if(bjmID != NULL)
              {
                Batch_Job_Monitor_Item__c bjmi = new Batch_Job_Monitor_Item__c();
                bjmi.Parent_Job_Monitor__c = bjmID;
                bjmi.Affected_record__c = sr.getId();
      
                bjmi.Error_Phase__c = 'EXECUTE-M';
                bjmi.Message__c = errmsg;
                bjmis.add(bjmi);
              }
            else 
              {
              System.Debug('Used durign debug. error: '+ errmsg);
              }     
          }
        }
      }

      if (BJMIs.size() > 0) {
        Database.insert(bjmis, false);
      }

      return retval;
    }  
    
    /*********************************************************************************************
    
    *********************************************************************************************/
    public static Set<ID> processDBSaveResult(List<Database.SaveResult> durs, Set<String> errmsg )
    {
     Set<ID> newRecordIDs = new Set<ID>(); 
     for(Database.SaveResult dur :durs) 
       {
       if(dur.isSuccess())
          {
           newRecordIDs.add(dur.getId());
          }
       else 
          {
          for(Database.Error de :dur.getErrors())
             {
              errmsg.add('upsert Error: ' + de.message);  
              System.Debug('ObjType upsert Error: ' + de.message); 
             } 
          }   
       } 
    
     return newRecordIDs;    
    }      
}