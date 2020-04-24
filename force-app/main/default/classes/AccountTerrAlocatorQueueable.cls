/***************************************************************************************************
class is not really used a squeueable.  We  started in this way  but  at the end we are using one of
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
********************************************************************************************/
  public static batchProcessAccountAlocator.AlocationResult checkAlignmentProcess(
    Set<ID> sA2A
  ) {
    batchProcessAccountAlocator.AlocationResult retval = new batchProcessAccountAlocator.AlocationResult();
    //List<Account> account2U =  new List<Account>();

    List<SObject> accOpp2Update = new List<SObject>();
    List<SObject> opp2Update = new List<SObject>(); //add opps  first to this list them add it to the above to avoid chunk error.  (Cannot have more than 10 chunks in a single operation)

    List<Account> afterAllocationAccs = [
      SELECT
        Id,
        TerritoryName__c,
        TerritoryName_Suggested__c,
        Need_Alignment__c,
        (
          SELECT
            id,
            AssociationCause,
            ObjectId,
            Territory2Id,
            Territory2.Name,
            LastModifieddate
          FROM ObjectTerritory2Associations
          WHERE IsDeleted = false
        ),
        (
          SELECT Id, Createddate, StageName, Territory2Id
          FROM Opportunities
          WHERE
            CloseDate > TODAY
            AND StageName IN (
              'Attempting',
              'Inbound',
              'Inbound Follow Up',
              'Engaged',
              'Marketing Qualified'
            )
        )
      FROM Account
      WHERE id IN :sA2A
    ];

    //List<Opportunity> Opps2PassTerritory =  new List<Opportunity>();
    for (Account a : afterAllocationAccs) {
      String terrName2match = a.TerritoryName__c;
      ID matchedOTAID;
      ID matchedT2ID;
      for (
        ObjectTerritory2Association newOTA : a.ObjectTerritory2Associations
      ) {
        if (newOTA.Territory2.Name == terrName2match) {
          matchedOTAID = newOTA.id;
          matchedT2ID = newOTA.Territory2Id;
          retval.Success = retval.Success + 1;
          break;
        }
      }

      if (matchedOTAID == null) {
        retval.Failure = retval.Failure + 1;
        continue; //this mean allocation Attempt was a failed (TBC)
      }

      a.Need_Alignment__c = false; //we had a succesfull allocation. Clear the flag
      //account2U.add(a);
      accOpp2Update.add(a);

      //check Custom MetadataType to see if propagate to Opps
      if (synchOpps == false) {
        continue;
      }

      //pass Territory2Id to Opportunities.
      for (Opportunity opp : a.Opportunities) {
        if (opp.Territory2Id != matchedT2ID) {
          opp.Territory2Id = matchedT2ID;
          opp2Update.add(opp);
        }
      }
    }

    if (opp2Update.size() > 0) {
      accOpp2Update.addAll(opp2Update);
    }

    if (accOpp2Update.size() > 0) {
      Database.update(accOpp2Update);
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