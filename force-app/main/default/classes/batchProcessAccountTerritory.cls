/**************************************************************************************************
   Run it by region to calculate the right TerritoryName for all account in the Alignment Window
   for each region include in the Account query the fields involved in Territory rules for that GEO
**************************************************************************************************/
global class batchProcessAccountTerritory implements Database.Batchable<sObject>, Database.Stateful, schedulable, Database.RaisesPlatformEvents {
  global String theGEO;   //the current GEO
  global String allGEOs = 'APAC;LATAM,EMEA;NORAM;CHINA';  

  global ID theAccId; //used when testing with 1 account
  global integer thelimit; //used when testing
  private Boolean isTest = false; //used when testing

  private Boolean isPilot = false; //take it from CMT and if true do not set TerrName but TerrNameSuggested only
  private Boolean isCascaded = true; //take it from CMT and if true we call bacth again for the next region
  private Boolean synchOpps = true;
  private Boolean includeMissing = false; //if true we add a where clause for Accoutn without TerrName

  //variables used in Monitoring.
  global integer totalMatched = 0;
  global integer totalMissed = 0;
  global integer totalFrozen = 0;
  global integer totalUnchanged = 0;
  global integer totalUpdated = 0;
  global Batch_Job_Monitor__c theBJM;

  private String startingDate; //read from Custom Metadata Type
  private String endingDate; //read from Custom Metadata Type  
  private String accFielList; //read from Custom Metadata Type

  @testvisible private String query; //put it here to be reachable from test

/**************************************************************************************
Constructor called during tests or when want to align 1 account AND FROM PROD SCHEDULER
**************************************************************************************/
  public batchProcessAccountTerritory(
    String geo,
    ID testAccID,
    Integer testAccountCount
  ) {
    this(geo);

    if (testAccID != null) {
      theAccId = testAccID;
    }
    if (testAccountCount != null) {
      thelimit = testAccountCount;
    }
    if (this.thelimit != null || this.theAccId != null) {
      isTest = true;
    } //remove theAccId
  }

  /***********************************************
  
  **********************************************/
  public batchProcessAccountTerritory(String geo) {
    theGEO = geo;

    /*******************************************
    TerritoryRelevantAFields__mdt trfCMT = [
      SELECT
        FieldList__c,
        Date2StartAlignment__c,
        Date2EndAlignment__c,
        isPilot__c,
        CascadeRegions__c,
        SyncOppTerritory__c,
        handleMissingTerr__c
      FROM TerritoryRelevantAFields__mdt
    ];
    *******************************************/

    TerritoryRelevantAFields__mdt trfCMT = getTRFCMT(geo);

    if (trfCMT == null) 
    {
      return;
    }

    accFielList = trfCMT.FieldList__c;
    isPilot = trfCMT.isPilot__c;
    isCascaded = trfCMT.CascadeRegions__c;
    synchOpps = trfCMT.SyncOppTerritory__c;
    includeMissing = trfCMT.handleMissingTerr__c;

    allGEOs = trfCMT.List_of_GEO__c != NULL?trfCMT.List_of_GEO__c:allGEOs;

    if (trfCMT.Date2StartAlignment__c != null) {
      startingDate =
        String.valueOf(trfCMT.Date2StartAlignment__c).left(10) +
        'T00:00:00.000Z'; //format it to SOQL or Trucate it  to date only
    }

    //2020.01.31.
    if (trfCMT.Date2EndAlignment__c != null) {
      endingDate =
        String.valueOf(trfCMT.Date2EndAlignment__c).left(10) +
        'T00:00:00.000Z'; //format it to SOQL or Trucate it  to date only
    }    

  }

  

  /************************************
   in order to schedule it we need  a
   parameterless constructor. BUT THIS
   IS NOT THE ONE INVOKED BY SCHEDULER!
  ************************************/
  public batchProcessAccountTerritory() 
  {
    this('APAC'); 
  }

  /*****************************************
  include Schedulable call in the same class
  *****************************************/
  global void execute(SchedulableContext sc) 
  {   
    batchProcessAccountTerritory batch = new batchProcessAccountTerritory(
      'APAC',
      null,
      null  
    );
    Database.executebatch(batch, 50); //keep low due to Acc./Opp. update
  }

  /***************************************************************
collect all NEW account which migth be affected by the Territory
related field changes
Collect inner opportunities to detect territory Frozen Accounts
***************************************************************/
  global Database.QueryLocator start(Database.BatchableContext bc) {
    Id bcId = bc == NULL?NULL:bc.getJobId();
    theBJM = batchProcessAccountAlocator.CreateBatchMonitor(
      bcId,
      'batchProcessAccountTerritory',
      0,
      0,
      'FindTErrName: ' + theGEO
    );

    query = 'Select Id, Name, TerritoryGeo__c,TerritoryTeam__c,TerritoryMarket__c,TerritorySegment__c,TerritoryName__c ,TerritoryName_Suggested__c,temp_AllocatorID__c,FreezeAlignment__c,Need_Alignment__c, ';
    String allTerrRelevantfields = 'ShippingState,Top_Parent_Billing_Location__c,Top_Parent_Billing_Country__c,Sector__c,Org_Type__c,Institution_FTE__c,segment__c,Parent_Account_Segment__c,Top_Parent_Org_Size__c,Org_Size__c,Employee_Count__c,ShippingPostalCode,ShippingPostalCode4Terr__c,Name4Terr__c,Primary_Business__c';
    if (accFielList != null) {
      allTerrRelevantfields = accFielList;
    }

    query = query + allTerrRelevantfields;

    query =
      query +
      ' ,(Select Id,Createddate, StageName,Territory2Id from Opportunities where CloseDate > TODAY ) '; //include here those opportunities which reached the Need Approval stage. If there is at least one DO NOT TOUCH the Account's Territory!

    query = query + ' from Account ';

    query = query + ' where TerritoryGeo__c = \'' + theGEO +  '\' ';

    //2020.04.22. add ES-36003  logic to the code. If not alligned yet overrule Freeze
    if (includeMissing == true) 
    {
      query = query + ' and (FreezeAlignment__c = false OR TerritoryName__c = NULL )';
    }  
    else 
    {
      query = query + ' and FreezeAlignment__c = false ';
    }
    //2020.04.22. add ES-36003  logic to the code

    if (startingDate != null) {
      query = query + ' and CreatedDate >= ' + startingDate;
    }

    if (endingDate != null) {
      query = query + ' and CreatedDate <= ' + endingDate;
    }    



    /****************** testing related WHERE clauses ***********************/
    if (theAccId != null) {
      query = query + ' and ID = \'' + theAccId + '\'';
    }

    if (thelimit == null) {
      query = query + ' limit 500000 ';
    } else {
      query = query + ' limit ' + String.valueof(thelimit);
    }
    /****************** testing related WHERE clauses ***********************/
    System.Debug('CSABA queryu = ' + query);
    return Database.getQueryLocator(query);
  }

  /*********************************************************************

*********************************************************************/
  global void execute(Database.BatchableContext bc, List<sObject> scope) {
    List<Account> theRealAcc2Update = new List<Account>();
    List<Account> acc2Freeze = new List<Account>();
    List<Account> accsMissed = new List<Account>();

    List<Opportunity> oppsNeedTeamMember = new List<Opportunity>();

    Set<ID> theRealRemainingIDs = new Set<ID>();
    map<ID, Account> mapAId2Account = new Map<ID, Account>(); 

    for (Account theA : (List<Account>) scope) {
      //exclude Accounts with certain opp and mark account
      List<Opportunity> oppsNeedTeam4A = getOpps4FrozenAccounts(theA);
      //ES-36003 if the Account is already frozen, or Just to be frozen BUT
      //TerritoryName__c = NULL and includeMissing = TRUE we NEED Alignment
      Boolean doNeed = theA.TerritoryName__c == NULL && includeMissing == TRUE?true:false;

      if (oppsNeedTeam4A != null) 
      {
        if(oppsNeedTeam4A.size() > 0)
           {
            oppsNeedTeamMember.addAll(oppsNeedTeam4A);
           }

        markAccountForbidden(theA);
        totalFrozen++;
        System.Debug('CSABA totalFrozen = ' + totalFrozen + ' isTest = ' + isTest);
        if ( isTest == false && doNeed == false)  //ES-36003 
        {
          acc2Freeze.add(theA);
          continue;
        }
      }

      mapAId2Account.put(theA.id, theA);
      theRealRemainingIDs.add(theA.id);
    } //end for loop

    Integer matched = 0;
    Integer missed = 0;
    Integer unchanged = 0;

    for (ID theA : theRealRemainingIDs) {
      Account account2MAtch = mapAId2Account.get(theA);

      TerritoryAllocator__c matchedTerr = AccountTerrNameBuilderQueueable.FindTerritoryName4Account(
        account2MAtch,
        isPilot
      );
      if (matchedTerr == null) {
        missed++;
        if (
          account2MAtch.TerritoryName_Suggested__c != 'MISSED' ||
          account2MAtch.Need_Alignment__c == true
        ) {
          account2MAtch.TerritoryName_Suggested__c = 'MISSED';
          account2MAtch.Need_Alignment__c = false;
          accsMissed.add(account2MAtch);
        } else if (account2MAtch.TerritoryName_Suggested__c == 'MISSED') {
          unchanged++;
        }
      } else {
        matched++;
        if (account2MAtch.Need_Alignment__c == false) {
          unchanged++;
        } else {
          theRealAcc2Update.add(account2MAtch);
        }
      }
    } //end of for

    totalMissed = totalMissed + missed;
    totalMatched = totalMatched + matched;
    totalUnchanged = totalUnchanged + unchanged;

    List<Account> accounts2update = new List<Account>();
    if (theRealAcc2Update.size() > 0) {
      accounts2update.addall(theRealAcc2Update);
    }

    if (acc2Freeze.size() > 0) {
      accounts2update.addall(acc2Freeze);
    }

    if (accsMissed.size() > 0) {
      accounts2update.addall(accsMissed);
    }

    List<Database.saveResult> dbsr;
    if (accounts2update.size() > 0) {
      dbsr = Database.Update(accounts2update);
      if (theBJM != null && theBJM.comment__c == 'High') {
        totalUpdated = totalUpdated + ProcessDBSaveResults(dbsr, theBJM.id);
      }
    }

    if (synchOpps) {
      GetOppTeamMembers(oppsNeedTeamMember); //some return value would help
    }
  }

  /***************************************************************
iterate through the opps of the Account and if NeedApproval+ opp
was found Account should be frozen and the early stage opps need
the OppTeam Member
Needs Approval
Sales Validating
Re-Qualify
Qualified
Evaluating
Shortlist
Negotiation
Payment Requested
Closed Won
Closed DeBook Quota
Closed Debooked Non-Quota
Closed Lost  

retval: lisf of Opps  with stageName < NeedApproval if there is
at leas 1  opp with StageName > NeedApproval 
OTHERWISE return NULL (this is the regular non-frozen path)
LOGIC OVERRULED: In case we found Opp Need Approval we need all
After Go live all Account which need freeze are relativelly new 
Accounts so all of their Opps need Opportunity Team Members.
***************************************************************/

  private List<Opportunity> getOpps4FrozenAccounts(Account theA) {
    List<Opportunity> retval = new List<Opportunity>();
    Boolean needForbidden = false;
    Set<String> forbiddedSates = new Set<String>{
      'Needs Approval',
      'Sales Validating',
      'Re-Qualify',
      'Qualified',
      'Evaluating',
      'Shortlist',
      'Negotiation',
      'Payment Requested'
    };
    //WE DO NOT RUN THIS FOR HISTORICA DATA
    List<Opportunity> opps4Acc = theA.Opportunities;
    for (Opportunity theO : opps4Acc) {
      if (forbiddedSates.contains(theO.stageName)) {
        needForbidden = true;
      }
      //else //WE need OppTeam Member for the Opp which reached the forbidden state because this is the last chance when we set OppTeamMember from here

      if (theO.Territory2Id != null) {
        retval.add(theO);
      }
    }

    if (needForbidden == true) {
      return retval;
    }

    return null;
  }

  /**********************************************
  2019.10.23. No idea why when isTest we do not
  set the Market/Segment/Team values.
  **********************************************/
  private void markAccountForbidden(Account theA) {

    if(theA.FreezeAlignment__c == true)
      {//36003 if already frozen don't repeat 
      return;  
      } 
     
    theA.FreezeAlignment__c = true;
    theA.Need_Alignment__c = false; //BINGO
    /****************************************
    at this point you can transferr here the
    final Territory Team/Market/Segment. TB2C
    split the T/M/S
    (36003) if contain '=' split again for "=" 
    *****************************************/
    String theTMS = theA.temp_AllocatorID__c;
    if (theTMS != null && theTMS.contains('/') && isTest == false) {
      string[] theTMSarray = theTMS.split('/');
      if (theTMSarray.size() == 3) 
      {
        //split again to  pick the piece after "="
        String tmsitem = getTMSpiece(theTMSarray[0]);
        if(tmsitem != NULL)
          {
          theA.TerritoryTeam__c = tmsitem;
          }

        tmsitem = getTMSpiece(theTMSarray[1]);
        if(tmsitem != NULL)
          {
          theA.TerritoryMarket__c = tmsitem;
          }        

        if (theA.TerritoryGeo__c != 'EMEA') 
        {
          tmsitem = getTMSpiece(theTMSarray[2]);          
          if(tmsitem != NULL)
          {
          theA.TerritorySegment__c = tmsitem;
          }   
        }
      }
    }
  }

  /*****************************************
  pick the value after the sign "=" if exist 
  36003
  *****************************************/
  private string getTMSpiece(String tmsitem)
  {
   String retval;
   if(tmsitem == NULL  || tmsitem.indexof('=') == -1)
      {
      return tmsitem;
      }
  
  string[] items = tmsitem.split('=');
  retval = items[1];   

   return retval;
  }

  /***************************************************** 
call Daniel's invocable to get Opportunity TeamMembers
*****************************************************/
  private void getOppTeamMembers(List<Opportunity> opps) {
    if (opps.size() == 0) {
      return;
    }

    TerritoryUtil.createOppTeams(opps);
  }

  /**************************************************************************************
  iterate through SaveResult and in case of error write to BatchJob_MonitorItem or if the
  parameter2 is NULL just display a debug msg. THIS method  should  be transferred into a
  generic class where BatchJobMonitor related code are stored to be used by other classes
  **************************************************************************************/
  @testvisible
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

  /***********************************************
Store statictics and call next Batch if exists.
***********************************************/
  global void finish(Database.BatchableContext bc) {
    String thecomment =
      this.theGEO +
      ':  TMatch = ' +
      totalMatched +
      ' TMissed = ' +
      totalMissed +
      ' TUnchanged = ' +
      totalUnchanged +
      ' TFrozen = ' +
      totalFrozen +
      ' Succesfully Updated = ' +
      totalUpdated;
    batchProcessAccountAlocator.CreateBatchMonitor(
      bc.getJobId(),
      'batchProcessAccountTerritory',
      totalMatched,
      totalMissed,
      thecomment
    );

    if (theAccId != null || Test.isRunningTest() == true) {
      return;
    } //in 1 account mode don't call other GEOs

    if (isCascaded == false) {
      return;
    }

    batchProcessAccountTerritory batchu; //call the batch for the next GEO
    String nextGEO = this.getNextGeo(this.theGEO, this.allGEOs);
    if(nextGEO != NULL)
       {
        batchu = new batchProcessAccountTerritory(nextGEO, theAccId, thelimit);
        Id batchJobId = Database.executeBatch(batchu, 50);
       }
    else 
       {
        Integer norofacc;
        batchProcessAccountAlocator batchuAlloc = new batchProcessAccountAlocator(norofacc);
        ID baID = Database.executeBatch(batchuAlloc, 10);      
       }   

    /***************************************************************************
     if (this.theGEO == 'APAC') {
      batchu = new batchProcessAccountTerritory('LATAM', theAccId, thelimit);
    } else if (theGeo == 'LATAM') {
      batchu = new batchProcessAccountTerritory('EMEA', theAccId, thelimit);
    } else if (theGEO == 'EMEA') {
      batchu = new batchProcessAccountTerritory('NORAM', theAccId, thelimit);
    } else if (theGEO == 'NORAM') {
      Integer norofacc;
      batchProcessAccountAlocator batchuAlloc = new batchProcessAccountAlocator(
        norofacc
      );
      ID baID = Database.executeBatch(batchuAlloc, 10);
    }

    if (batchu != null) {
      Id batchJobId = Database.executeBatch(batchu, 50);
    } 
    ***************************************************************************/

  }

  /******************************** Make GEO configurable **********************************/
  
  /******************************************************************
  Get the TerritoryRelevantField CMT and its child CMT item(not used) 
  ******************************************************************/
  private TerritoryRelevantAFields__mdt getTRFCMT(String currentGEO)
  {
    TerritoryRelevantAFields__mdt trfCMT = [
      SELECT
        FieldList__c,
        Date2StartAlignment__c,
        Date2EndAlignment__c,
        isPilot__c,
        CascadeRegions__c,
        SyncOppTerritory__c,
        handleMissingTerr__c
        ,List_of_GEO__c
        //,(Select id,DeveloperName,GeoRelevantFields__c  from TerritoryGeoItems__r where DeveloperName = :currentGEO)
      FROM TerritoryRelevantAFields__mdt
    ]; 
    
    return trfCMT;
  }


  /**********************************************************
  invoked from the Finihh method to decide which GEO to call.
  **********************************************************/
  private String getNextGeo(String currentGeo,String allGeos)
  {
  String[] geos = allGeos.split(';');
  integer geoCount = geos.size();
  if(currentGeo == geos[geoCount-1])
    {
    return NULL; //no more GEO. Game Over  
    }

  for(integer i = 0; i < geoCount; i++)
     {
     if(currentGeo == geos[i])
       {
       return geos[i+1];  
       } 
     }

  return null;     
  }

}