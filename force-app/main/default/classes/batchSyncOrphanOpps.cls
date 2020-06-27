/************************************************************************************************************************
 * 
 * 
************************************************************************************************************************/
global class batchSyncOrphanOpps implements Database.Batchable<sObject>, Database.Stateful, Database.RaisesPlatformEvents
{
    @testvisible private String query; //put it here to be reachable from test    

    //variables used in Monitoring.
    global integer EFOppsCount = 0;
    global integer LFOppsCount = 0;
    global integer totalDMLSuccess = 0;
    global integer totalDMLFailures = 0;
    

    //add BJM functionality to the class
    global Batch_Job_Monitor__c theBJM;     
    
    public batchSyncOrphanOpps() 
    {
    query = CMT_QueryBuilder.buildSOQLfromCMT('OppQuery4TerrSync');
    }

    /***************************************************************
    attach BJm to the class, Read Query from CMT
    ***************************************************************/
    global Database.QueryLocator start(Database.BatchableContext bc) 
    {
    Id bcId = bc == NULL?NULL:bc.getJobId();
    batchJobMonitorUtility.attachBJM2Class(bcId,theBJM);

    Database.QueryLocator dql;  
    try 
    {
      dql = Database.getQueryLocator(query);     
    } 
    catch (Exception myexc) 
    {
      query = 'Select ID, AccountId, StageName,Territory2ID, Territory2.Name,TerritorySyncStatus__c from Opportunity ';
      query = query +  'where Account.CreatedDate > 2020-02-01T00:31:03.000Z and Closed = false '; 
      query = query + ' and ( (Territory2ID = NULL and StageName in (\'Needs Approval\',\'Sales Validating\',\'Re-Qualify\',\'Qualified\',\'Evaluating\',\'Shortlist\',\'Negotiation\',\'Payment Requested\') )';
      query = query + 'OR (TerritorySyncStatus__c = FALSE and StageName in (\'Attempting\',\'Inbound\',\'Inbound Follow Up\',\'Engaged\',\'Marketing Qualified\') )  )';
      dql = Database.getQueryLocator(query);      
    }
    
    System.Debug('CSABA queryu = ' + query);
    return dql;    
    }


    /*************************************************************************
    Get the Territory Id of the Accounts of the Opps .in the scope and pass it
    the the Opportunities in Scope.
    *************************************************************************/
    global void execute(Database.BatchableContext bc, List<Opportunity> scope) 
    {    
        Set<ID> oppAccIds = new Set<ID>();
        Set<ID> oppIds =  new Set<ID>();

        Set<String> LateFunnelStage = new Set<String>{
          'Needs Approval',
          'Sales Validating',
          'Re-Qualify',
          'Qualified',
          'Evaluating',
          'Shortlist',
          'Negotiation',
          'Payment Requested'
        };   
        
        for(Opportunity opp :scope)
        {
            oppIds.add(opp.id);
            oppAccIDs.add(opp.AccountID);    
        }

        List<Account> parentAccounts = [
            SELECT Id,Name,TerritoryName__c,TerritoryName_Suggested__c, Need_Alignment__c,FreezeAlignment__c,
              (
                SELECT id,Territory2Id,Territory2.Name
                FROM ObjectTerritory2Associations
                WHERE IsDeleted = false and Territory2.Territory2Model.State = 'Active' 
               ),
              (
                SELECT Id, Createddate, StageName, Territory2Id,TerritorySyncStatus__c    
                FROM Opportunities where id in :oppIds
              )
            FROM Account
            WHERE id IN :oppAccIDs
          ];
        
        System.Debug('CSABA accounrs involed: ' + parentAccounts.size()); 
        List<Opportunity> opps2Sync = new List<Opportunity>();
        for(Account acc :parentAccounts)
        {
        ID  terr2syncWith;
        //we should have only 1 Active terr. pick its ID and pass it to Opp
        for(ObjectTerritory2Association newOTA : acc.ObjectTerritory2Associations) 
           {
            terr2syncWith = newOTA.Territory2Id;
            break;
           }
        System.Debug('CSABA terr2syncWith = ' + terr2syncWith); 
        if(terr2syncWith == NULL) { continue; }   
        //pass it only if ID not null. pass it even 
        //if it not the desired Territorry!    
        For(Opportunity opp2Sync :acc.Opportunities)
            {
            opp2Sync.Territory2Id = terr2syncWith;
            opps2Sync.add(opp2Sync);
            System.Debug('CSABA opp2Sync.StageName = ' + opp2Sync.StageName);  
            if(LateFunnelStage.contains(opp2Sync.StageName))
               {
                LFOppsCount++;
               }
            else 
               {
                EFOppsCount++;
               }   
             
            }
        }  

        integer opps2snccount = opps2Sync.size();
        if(opps2snccount > 0)
           {
            //List<Database.SaveResult> drsrs = Database.update(opps2Sync, false); 
            //ID bjmidu = theBJM.id != NULL?theBJM.id:NULL;
            //Integer success = batchProcessAccountTerritory.processDBSaveResults(drsrs,bjmidu);  
            //totalDMLSuccess = totalDMLSuccess + success;
            //totalDMLFailure = totalDMLFailure + opps2snccount -success;
           }

    }

    /***********************************************
    write the statistics info into the attached BJM.
    ***********************************************/
    global void finish(Database.BatchableContext bc) 
    {
      String comment = 'EarlyFunnel Opps = ' + String.valueOf(EFOppsCount) + ' , LateFunnel Opps = ' + String.valueOf(LFOppsCount);
      batchJobMonitorUtility.CreateBatchMonitor(
        bc.getJobId(),
        'batchSyncOrphanOpps',
        totalDMLSuccess,        
        totalDMLFailures,
        comment
      );
    }   
    

}