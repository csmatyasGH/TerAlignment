/***************************************************************************************************
class is not really used as queueable.  We  started in this way  but  at the end we are using one of
its method (AllignAccountSoap) from a batch class
***************************************************************************************************/
public with sharing class AccountTerrAlocatorQueueable implements Queueable, Database.AllowsCallouts {
  public Set<ID> accountIDs2Align = new Set<ID>();

  public AccountTerrAlocatorQueueable(Set<ID> accountID) {
    accountIDs2Align = accountID;
  }

  /********************************************
  it might be used only when we align Accounts
  in real time when became 100% alignmentReady
  ********************************************/
  public void execute(QueueableContext context) {
    AllignAccountSoap(accountIDs2Align);
    checkAlignmentProcess(accountIDs2Align);
  }

  /**********************************************************************************************
Force alignment for the Account IDs passed as param native Apex does not support this. I had to
export  PartnerWSDL and reload into the org to make a callout from Salesforce 2 Salesforce.
**********************************************************************************************/
  public static List<partnerSoapSforceCom.SaveResult> allignAccountSoap(
    Set<ID> accountIDs2Align
  ) {
    List<partnerSoapSforceCom.SaveResult> retval;
    partnerSoapSforceCom.Soap soapObj = new partnerSoapSforceCom.Soap();

    soapObj.SessionHeader = new partnerSoapSforceCom.SessionHeader_element();

    String myurlu = String.valueof(System.URL.getOrgDomainUrl());
    Integer indeofEQ = myurlu.indexof('=');
    myurlu = myurlu.right(myurlu.length() - indeofEQ - 1);
    myurlu = myurlu.remove(']');
    myurlu = myurlu + '/services/Soap/u/45.0/' + UserInfo.getOrganizationId();
    soapObj.endpoint_x = myurlu;

    String newsessionId = Test.isRunningTest() == true
      ? System.UserInfo.getUserId()
      : Page.vfp_SessionId_Getter.getContent().toString();
    soapObj.Sessionheader.sessionid = newsessionId;

    List<sobjectPartnerSoapSforceCom.sObject_x> lst = new List<sobjectPartnerSoapSforceCom.sObject_x>();

    for (ID theAccID : accountIDs2Align) {
      sobjectPartnerSoapSforceCom.sObject_x tmpObj = new sobjectPartnerSoapSforceCom.sObject_x();
      tmpObj.type_x = 'Account';
      tmpObj.Id = theAccID;
      lst.add(tmpObj);
    }

    partnerSoapSforceCom.AssignmentRuleHeader_element obj1 = new partnerSoapSforceCom.AssignmentRuleHeader_element();
    obj1.useDefaultRule = true;
    soapObj.AssignmentRuleHeader = obj1;

    retval = soapObj.update_x(lst);

    return retval;
  }
  /********************************************************************************************
iterate through the Accounts and check if aligned properly. If yes clear Need_Alignment flag
return:  object holding nr of Success/Failures statistics.

******************* re-think which Opps are in scope for cascading!!!!!! ********************
we should not use Opp sync when run Alignment for historical data (EMEA or non-aligned NORAM)
we should sync only for new Accounts BUT in this case  we should not  care about Opp Stage
Accounts with Opps after Need-Approval stage should not even reach the alignment because were
filtered out by the batchProcesAccountTerritory class

2020.04.29. Rething a bit the returned value. We should return the Database.SaveResult too in
order to store statistic result in the caller batch. (I would like to track the Opp. sync.)
add a new member to the AlocationResult  class to store  the SaveResult list
********************************************************************************************/
  public static batchProcessAccountAlocator.AlocationResult checkAlignmentProcess(
    Set<ID> sA2A
  ) {
    batchProcessAccountAlocator.AlocationResult retval = new batchProcessAccountAlocator.AlocationResult();
    //REMARK: in the future this list of Late Stage opp might change. Make this configurable from outside. 
    Set<String> forbiddedSates = new Set<String>{
      'Needs Approval',
      'Sales Validating',
      'Re-Qualify',
      'Qualified',
      'Evaluating',
      'Shortlist',
      'Negotiation',
      'Payment Requested'
    }; //(ES-36003)

    List<SObject> accOpp2Update = new List<SObject>();                  //Cannot have more than 10 chunks in a single operation
    List<SObject> opp2Update = new List<SObject>(); //add opps first to this list them add it to the above to avoid chunk error.  

    List<Account> afterAllocationAccs = [
      SELECT
        Id,
        Name,
        TerritoryName__c,
        TerritoryName_Suggested__c,
        Need_Alignment__c,
        FreezeAlignment__c,
        (
          SELECT
            id,
            AssociationCause,
            ObjectId,
            Territory2Id,
            Territory2.Name,
            LastModifieddate
          FROM ObjectTerritory2Associations
          WHERE IsDeleted = false and Territory2.Territory2Model.State = 'Active' //36003. we can insert only  ACTIVE  Terr into OTA but old Territories are not deleted when INACTIVATED
         ),
        (
          SELECT Id, Createddate, StageName, Territory2Id    
          FROM Opportunities
          WHERE
            CloseDate > TODAY              // isclosed = false
            AND (StageName IN (           //include here all EARLY FUNNEL opportunities which need to be kept in sync
              'Attempting',
              'Inbound',
              'Inbound Follow Up',
              'Engaged',
              'Marketing Qualified'
            )
            OR Territory2Id = null)      //include here Open opps without Territory regardless to Funnel position
        )
      FROM Account
      WHERE id IN :sA2A
    ];

    /*************************************
    check if the Account aligned Territory
    match with the one in Territory_Name.
    If MATCH try to synchronize Opps too.
     ************************************/
    for (Account a : afterAllocationAccs) 
    {
      String terrName2match = a.TerritoryName__c;
      ID matchedOTAID;
      ID matchedT2ID;

      for (ObjectTerritory2Association newOTA : a.ObjectTerritory2Associations) 
      {
        if (newOTA.Territory2.Name == terrName2match) 
        {
          matchedOTAID = newOTA.id;
          matchedT2ID = newOTA.Territory2Id;
          retval.Success = retval.Success + 1;
          break;
        }
      }

      if (matchedOTAID == null) 
      {
        retval.Failure = retval.Failure + 1;
        continue; 
      }
      System.Debug('CSABA we have a MATCHING TERRITORY');
      a.Need_Alignment__c = false; 

      accOpp2Update.add(a);

      
      if (synchOpps == false) {
        continue;   //check Custom MetadataType to see if propagate to Opps
      }
      
      System.Debug('we have Opps to sync: ' + a.Opportunities.size());
      //pass Territory2Id to Opportunities.
      for (Opportunity opp : a.Opportunities) 
      {
        /************************************
        Here we can have Open Opportunities. 
        In the majority of  the cases these 
        are Early Stage opps which needs to 
        be kept in synch with their Account 

        (BUT we can have here late Stage Opps
        without TerritoryID. These can happen
        mainly in case of the accs which were 
        already Frozen, but missed Territory
        before this iteration OR if the acc.
        get stucked in Need Alignment phase
        and its opp progressed without being
        aligned.  ES-36003  )
        DO NOT LEAVE OPEN OPP WITHOUT TERR!!
        ************************************/
        if(opp.Territory2Id != matchedT2ID && forbiddedSates.contains(opp.stageName) == false)  
        {
          System.Debug('Early funnel opp need to be Matched. id= ' +  + opp.id);
          opp.Territory2Id = matchedT2ID; //here we handle the Eraly stage opp (normal path)
          opp2Update.add(opp);

          retval.EarlyFunnel_opps2_sync = retval.EarlyFunnel_opps2_sync + 1;  //2020.04.30.
        }

        if (opp.Territory2Id == NULL && forbiddedSates.contains(opp.stageName) == true)
        {
          System.Debug('Orphan Late funnel opp need to be Matched. id = ' + opp.id);          
          opp.Territory2Id = matchedT2ID; //here we handle the LateStage orphan opp (36003)
          opp2Update.add(opp);

          retval.LateFunnel_opps2_sync = retval.LateFunnel_opps2_sync + 1; //2020.04.30.
        }        

      }
    }

    //Ad the opps 2 update the a Generic list to havw 1 single update   
    if (opp2Update.size() > 0)  { accOpp2Update.addAll(opp2Update); }

    if (accOpp2Update.size() > 0) 
    {
      //add debug 4 saveresult. put processDBSaveResults in an utility class
      List<Database.SaveResult> drsrs = Database.update(accOpp2Update,false);
      //integer retval = batchProcessAccountTerritory.processDBSaveResults(drsrs,NULL);
      retval.setDbSaveResult(drsrs);  //2020.04.29. try  to return the info about the DML.
    }

    return retval;
  }

  /*******************************
  read Custom Metadata Type into a
  property This decide if we synch
  the Account Terr. with the Opps.
  *******************************/
  private static Boolean synchOpps {
    get {
      if (synchOpps == null) {
        TerritoryRelevantAFields__mdt trfCMT = [
          SELECT SyncOppTerritory__c
          FROM TerritoryRelevantAFields__mdt
          LIMIT 1
        ];
        if (trfCMT == null) {
          synchOpps = false;
        } else {
          synchOpps = trfCMT.SyncOppTerritory__c;
        }
      }
      return synchOpps;
    }
    set;
  }
}