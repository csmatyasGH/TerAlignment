/***************************************
class provide support for TerritoryName
calculation for 1 Account using PB/FLOW
and Accoutn field enrichment
***************************************/
public without sharing class AccountTerritoryNameBuilder {
  static ID queueID = null; //use a static variable to avoid recursive call

  /*****************************************************************************************************
Used to prepare the Account for Process Builder and FLOW
return value = the found TerrAllocator record or NULL.
*****************************************************************************************************/
  @InvocableMethod(label='Build Terr items')
  public static List<TerritoryAllocator__c> accountTerritoryNameBuilder(
    List<TerrBuilderWrapper> params
  ) {
    if (queueID != null) {
      return null;
    } //is called recursivelly. skip

    List<TerritoryAllocator__c> retval;
    String operation;
    String terr2M;

    Map<Id, Account> mpAcc2Proc = new Map<Id, Account>();
    Set<Id> accID2Proc = new Set<Id>();

    for (TerrBuilderWrapper tbw : params) {
      terr2M = tbw.TNS;
      operation = tbw.Operation;
      if (operation == 'BuildTerrName') {
        mpAcc2Proc.put(tbw.Accs2Process.Id, tbw.Accs2Process);
      }

      if (operation == 'AlignAcc' || operation == 'FindTerrName') {
        accID2Proc.add(tbw.AccID2Align);
      }
      if (
        operation == 'ready2Align' //2019.11.14
      ) {
        accID2Proc.add(tbw.Accs2Process.Id);
        mpAcc2Proc.put(tbw.Accs2Process.Id, tbw.Accs2Process);
      }
    }

    List<Account> matchedAccs = new List<Account>();
    switch on operation {
      when 'BuildTerrName' {
        /*** Called from PB to find SuggestedTerrName ***/
        Account theAcc2M = mpAcc2Proc.Values()[0].clone();
        theAcc2M.id = mpAcc2Proc.Values()[0].id;
        retval = go4Allocator(theAcc2M, 'PB', true);
      }
      when 'FindTerrName' {
        /** Called from FLOW to detect Allocator **/
        Account theAcc2M = getAccount2M(accID2Proc);
        if (theAcc2M == null) {
          return null;
        }
        retval = go4Allocator(theAcc2M, 'FLOW', false);
      }
      when 'AlignAcc' {
        /**********************************************************
			Called from FLOW when aligning account in Lightning Quick
			button based on the Territory foudn in the previous step.
			**********************************************************/

        AccountTerrAlocatorQueueable.AllignAccountSoap(AccID2Proc);

        List<TerritoryAllocator__c> inMemmoryAllocs = new List<TerritoryAllocator__c>();
        inMemmoryAllocs.add(ValidateAlignment(AccID2Proc, terr2M)); //used by caller FLOW

        retval = inMemmoryAllocs;
      }
      when 'ready2Align' {
        /***************************************************************
            CALLED FROM PB when the Account just became 100% Alignment Ready
			WE SHOULD FIND A WAY TO NOT CALL FROM BATCH WHEN ACCOUNT IS JUST
			ALIGNED!!!
			***************************************************************/
        Set<ID> acc2Align = new Set<ID>();
        for (Account a : mpAcc2Proc.Values()) {
          Account a2process = a.clone(); //PB is after update trigger
          a2process.id = a.id;
          retval = go4Allocator(a2process, 'FLOW', false);
          if (retval != null && retval[0].Name != 'Exception')
            acc2Align.add(a2process.id); //alloc found
        }
        queueID = System.enqueueJob(
          new AccountTerrAlocatorQueueable(acc2Align)
        );
      }
    }
    return retval; //if we are here we return null
  }

  /****************************************************************************************
Called in the FLOW to check if the Account was aligned to the territory passed in param2.
****************************************************************************************/
  public static TerritoryAllocator__c validateAlignment(
    Set<ID> accID2Proc,
    String terr2M
  ) {
    TerritoryAllocator__c retval;
    List<Opportunity> opp2Align = new List<Opportunity>(); //2019.10.11.
    //validate the Alignment by reading the ObjectTerritory2Association and compare Aligned TERR with the Terr2M
    List<Account> afterAllocationAccs = [
      SELECT
        Id,
        TerritoryName__c,
        TerritoryName_Suggested__c,
        Need_Alignment__c,
        FreezeAlignment__c,
        (
          SELECT id, AssociationCause, ObjectId, Territory2Id, Territory2.Name
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
      WHERE id IN :accID2Proc
    ];

    for (Account theA : afterAllocationAccs) {
      ID matchedTerr2ID; //2019.10.11.
      List<ObjectTerritory2Association> theOTAs = theA.ObjectTerritory2Associations;
      for (ObjectTerritory2Association ota : theOTAs) {
        if (ota.Territory2.Name == terr2M) {
          retval = new TerritoryAllocator__c(Name = 'matched');
          retval.Territory_Name__c = terr2M;
          matchedTerr2ID = ota.Territory2ID;
          break;
        }
      } //end for ObjectTerritory2Association

      if (
        matchedTerr2ID != null //2019.10.11.
      ) {
        for (Opportunity opp : theA.Opportunities) {
          if (opp.territory2ID == matchedTerr2ID) {
            continue;
          }
          opp.territory2ID = matchedTerr2ID;
          Opp2Align.add(opp);
        }
      }
    } //end for afterAllocationAccs

    if (retval == null) {
      //we must return a record to not have problem in the FLOW
      retval = new TerritoryAllocator__c(Name = 'No matched');
      retval.Territory_Name__c = 'Missed';
    }

    if (Opp2Align.size() > 0) {
      Database.update(Opp2Align);
    }
    return retval;
  }

  /*****************************************************
   Called from FLOW to gather custom settings-based fields
   Make it private and test visible
*****************************************************/
  public static Account getAccount2M(Set<ID> accID2Proc) {
    Account theAcc2M = [
      SELECT Id, TerritoryGeo__c
      FROM Account
      WHERE Id IN :accID2Proc
    ];
    List<TerritoryRelevantAFields__mdt> trfCMTs = [
      SELECT FieldList__c
      FROM TerritoryRelevantAFields__mdt
    ];
    if (trfCMTs.size() == 0) {
      return null;
    }

    String query = 'Select  Id,Name,TerritoryName_Suggested__c,TerritoryName__c,TerritoryGeo__c,TerritorySegment__c,TerritoryTeam__c,TerritoryMarket__c,FreezeAlignment__c,';
    query =
      query +
      trfCMTs[0].FieldList__c +
      ' from Account where Id = \'' +
      theAcc2M.id +
      '\''; //INCLUDE HERE QUERY FROM INNER OPPERTUNITY TO DETECT FREZE

    theAcc2M = Database.query(query);
    return theAcc2M;
  }
  /******************************************************************************************************
   called from Account PB  for  "BuildTerrNAme and from Flow  for "FindTerrName.
******************************************************************************************************/
  public static List<TerritoryAllocator__c> go4Allocator(
    Account theAcc2M,
    String caller,
    Boolean istest
  ) {
    TerritoryAllocator__c foundTerrAloc = AccountTerrNameBuilderQueueable.FindTerritoryName4Account(
      theAcc2M,
      istest
    );

    if (foundTerrAloc != null) {
      Account acc2OperateOn;
      if (caller == 'FLOW') {
        acc2OperateOn = theAcc2M;
      } else {
        acc2OperateOn = theAcc2M.clone();
        acc2OperateOn.id = theAcc2M.id;
      }

      acc2OperateOn.TerritoryName_Suggested__c = foundTerrAloc.Territory_Name__c;
      if (istest == false) {
        //probably useless since is done inside FindTerritoryName4Account.  2019.10.23.
        acc2OperateOn.TerritoryName__c = foundTerrAloc.Territory_Name__c;
        acc2OperateOn.TerritoryTeam__c = foundTerrAloc.TerritoryTeam__c;
        acc2OperateOn.TerritoryMarket__c = foundTerrAloc.Territory_Market__c;
        //acc2OperateOn.TerritorySegment__c = foundTerrAloc.Segment__c;
        if (acc2OperateOn.TerritoryGeo__c != 'EMEA') {
          acc2OperateOn.TerritorySegment__c = foundTerrAloc.Segment__c;
        }
      }
      acc2OperateOn.temp_AllocatorID__c =
        'T= ' +
        foundTerrAloc.TerritoryTeam__c +
        +' /M= ' +
        foundTerrAloc.Territory_Market__c +
        ' /S= ' +
        foundTerrAloc.Segment__c;

      try //we might have exception on update due to restrited picklist. Add some exception handling here
      {
        //create a dummy Allocator and the caller flow will display an warnign message.
        update Acc2OperateOn;
      } catch (Exception myEx) {
        foundTerrAloc.Name = 'Exception';
        foundTerrAloc.Territory_Name__c = myEx.getMessage();
      }

      return new List<TerritoryAllocator__c>{ foundTerrAloc };
    }
    return null;
  }

  /***********************************************************
Set Market/Segment/Postalcode4Terr in case any of the fields
involved in their formula has changed. Called by Acc Trigger
***********************************************************/
  public static void enrichAccounts(Account a, Account oldAcc) {
    if (System.isBatch() == true) {
      return;
    }

    //include Geo here.

    if (
      a.TerritoryMarket__c == null || //what if is not null? nothign change BUT is wrong?
      (oldAcc != null &&
      (a.Org_Type__c != oldAcc.Org_Type__c ||
      a.Primary_Business__c != oldAcc.Primary_Business__c))
    ) {
      setMarket(a);
    }

    if (
      a.TerritorySegment__c == null || //what if is not null? nothign change BUT is wrong?
      (oldAcc != null &&
      (a.Org_Type__c != oldAcc.Org_Type__c ||
      a.Primary_Business__c != oldAcc.Primary_Business__c ||
      a.TerritoryGeo__c != oldAcc.TerritoryGeo__c))
    ) {
      SetSegment(a);
    }

    setPostalCode4Terr(a, oldAcc);

    if (a.Name != null) {
      a.Name4Terr__c = a.Name.left(1);
    }

    Decimal readiness = a.Allignment_readiness__c;
    if (a.FreezeAlignment__c == false) {
      SetAlignmentReadyness(a);
    }
  }

  /***************************************************************
   Set it if empty or PostalCode changed
   2019.07.17. late call from Sagar.
   change from ShippingPostalCode to Top_Parent_Shipping_Code__c
***************************************************************/
  public static void setPostalCode4Terr(Account a, Account oldAcc) {
    //if((a.ShippingPostalCode4Terr__c == NULL && a.ShippingPostalCode != NULL)||  (oldAcc != NULL && a.ShippingPostalCode != oldAcc.ShippingPostalCode) )
    if (
      (a.ShippingPostalCode4Terr__c == null &&
      a.Top_Parent_Shipping_Code__c != null) ||
      (oldAcc != null &&
      a.Top_Parent_Shipping_Code__c != oldAcc.Top_Parent_Shipping_Code__c)
    ) {
      //a.ShippingPostalCode4Terr__c = a.ShippingPostalCode.left(5);
      a.ShippingPostalCode4Terr__c = a.Top_Parent_Shipping_Code__c.left(5);
    }
  }

  /**************************************
   Not sure we should do it here because
   is set before and After TerritoryName
**************************************/
  public static void setMarket(Account a) {
    //this section is  called before TerritoryName calculation attempt
    if (
      a.TerritoryGeo__c != 'EMEA' //a.TerritoryName__c == NULL &&
    ) {
      if (
        (a.Org_Type__c != 'Corporate' && a.Org_Type__c != 'Government') ||
        (a.Primary_Business__c == 'Higher Ed' ||
        a.Primary_Business__c == 'K12' ||
        a.Primary_Business__c == 'RTO/Training')
      ) {
        a.TerritoryMarket__c = 'EDU';
      } else if (
        (a.Org_Type__c == 'Corporate' || a.Org_Type__c == 'Government') ||
        (a.Primary_Business__c != 'Higher Ed' &&
        a.Primary_Business__c != 'K12' &&
        a.Primary_Business__c != 'RTO/Training' &&
        a.Primary_Business__c != 'Further Education')
      ) {
        a.TerritoryMarket__c = 'CORP';
      }
    } else {
      if (
        (a.Org_Type__c != 'Corporate' && a.Org_Type__c != 'Government') ||
        (a.Primary_Business__c == 'Higher Ed' ||
        a.Primary_Business__c == 'K12' ||
        a.Primary_Business__c == 'Further Education' ||
        a.Primary_Business__c == 'RTO/Training')
      ) {
        a.TerritoryMarket__c = 'EDU';
      } else if (
        (a.Org_Type__c == 'Corporate' || a.Org_Type__c == 'Government') ||
        (a.Primary_Business__c != 'Higher Ed' &&
        a.Primary_Business__c != 'K12' &&
        a.Primary_Business__c != 'RTO/Training' &&
        a.Primary_Business__c != 'Further Education')
      ) {
        a.TerritoryMarket__c = 'CORP';
      }
    }
  }

  /*****************************************

*****************************************/
  public static void setSegment(Account a) {
    switch on a.TerritoryGeo__c {
      when 'APAC' {
        if (
          a.Primary_Business__c == 'Higher Ed' ||
          (a.Org_Type__c != 'Corporate' &&
          a.Org_Type__c != 'Government' &&
          a.Org_Type__c != 'K12' &&
          a.Org_Type__c != 'Further Education' &&
          a.Org_Type__c != 'RTO/Training')
        ) {
          a.TerritorySegment__c = 'HIED'; //what if Org_Type = NULL and PB  != 'Hiegher Ed'
        } else if (
          a.Primary_Business__c == 'Higher Ed' ||
          a.Org_Type__c == 'K12'
        ) {
          a.TerritorySegment__c = 'K12';
        } else if (
          a.Org_Type__c == 'Further Education' ||
          a.Org_Type__c == 'RTO/Training'
        ) {
          a.TerritorySegment__c = 'RTO';
        } else if (
          a.Org_Type__c == 'Corporate' ||
          a.Org_Type__c == 'Government' ||
          (a.Primary_Business__c != 'Higher Ed' &&
          a.Primary_Business__c != 'K12' &&
          a.Primary_Business__c != 'Further Education' &&
          a.Primary_Business__c != 'RTO/Training')
        ) {
          a.TerritorySegment__c = 'CORP';
        }
      }
      when 'EMEA' {
        System.assert(true, 'EMEA does not have segment');
      }
      when 'LATAM' {
        a.TerritorySegment__c = 'HIED';
      }
      when 'NORAM' {
        if (
          a.Primary_Business__c == 'Higher Ed' ||
          (a.Org_Type__c != 'Corporate' &&
          a.Org_Type__c != 'Government' &&
          a.Org_Type__c != 'K12')
        ) {
          a.TerritorySegment__c = 'HIED';
        } else if (a.Primary_Business__c == 'K12' || a.Org_Type__c == 'K12') {
          a.TerritorySegment__c = 'K12';
        } else if (
          (a.Primary_Business__c != 'Higher Ed' &&
          a.Primary_Business__c != 'K12' &&
          a.Primary_Business__c != 'Further Education' &&
          a.Primary_Business__c != 'RTO/Training') ||
          (a.Org_Type__c == 'Corporate' ||
          a.Org_Type__c == 'Government')
        ) {
          a.TerritorySegment__c = 'MM';
        }
      }
    }
  }

  /******************************************************
Track the percentage of the Account Terr-Relevant field 
population. It depends on GEO and is stored in a custom 
settings or Can be retrieved from the Allocator Records 
APAC_TRF_List__c
LATAM_TRF_List__c
EMEA_TRF_List__c
NORAM_TRF_List__c
Return TRUE if the account just became ready for align
*****************************************************/
  public static Boolean setAlignmentReadyness(Account a) {
    Boolean retval = false;

    String geoTRF = mapGeoTRFList.get(a.TerritoryGeo__c);
    if (geoTRF == null) {
      return false;
    }

    List<String> fieldList = geoTRF.split(',');
    integer fieldcount = fieldList.size();
    if (fieldcount == 0) {
      return false;
    }

    integer counteru = 0;
    for (String fieldName : fieldList) {
      if (a.get(fieldName) != null) {
        counteru++;
      }
    }

    decimal rediness = 100 * counteru / fieldCount; //pass this to Account
    if (a.Allignment_readiness__c < 100 && rediness == 100) {
      retval = true;
    }
    //set tthe readiness here because theoretically we might go off readiness
    a.Allignment_readiness__c = rediness;

    return retval;
  }

  /***********************************************
Read the Geo dependent mandatory field list.
***********************************************/
  private static Map<String, String> mapGeoTRFList {
    get {
      if (mapGeoTRFList == null) {
        mapGeoTRFList = new Map<String, String>();
        for (TerritoryRelevantAFields__mdt trfcmt : [
          SELECT
            Id,
            APAC_TRF_List__c,
            LATAM_TRF_List__c,
            EMEA_TRF_List__c,
            NORAM_TRF_List__c
          FROM TerritoryRelevantAFields__mdt
        ]) {
          mapGeoTRFList.put('APAC', trfcmt.APAC_TRF_List__c);
          mapGeoTRFList.put('LATAM', trfcmt.LATAM_TRF_List__c);
          mapGeoTRFList.put('EMEA', trfcmt.EMEA_TRF_List__c);
          mapGeoTRFList.put('NORAM', trfcmt.NORAM_TRF_List__c);
        }
      }
      return mapGeoTRFList;
    }
    set;
  }

  /***********************************************************************************************************************************************
In case we have an active Parent BJM for this class create a worker BJM.

public static Batch_Job_Monitor__c createBatchMonitor(Id batchJobID, String batchClassName, Integer success, Integer failure, String theComment)
{
	List<Batch_Job_Monitor__c> parentBJMs = [Select Id, Log_Level__c from Batch_Job_Monitor__c 
	                                         where BatchClassName__c = :BatchClassName and Parent_BatchMonitor__c = NULL and Active__c = true 
											 limit 1
											 ];

	if(parentBJMs.size() == 0)  { return NULL; }

	Batch_Job_Monitor__c thenewBJM =  new Batch_Job_Monitor__c(Parent_BatchMonitor__c = parentBJMs[0].id, BatchClassName__c = batchClassName);
	thenewBJM.comment__c = theComment;
	thenewBJM.BatchJobID__c = batchJobID;
	thenewBJM.nrofSuccess__c = success;
	thenewBJM.NrofFailures__c = failure;
	//insert thenewBJM;
	Database.upsertresult durs = Database.upsert(thenewBJM,Batch_Job_Monitor__c.BatchJobID__c,false);
	thenewBJM.comment__c = parentBJMs[0].Log_Level__c;     //just to pass the loglevel back to caller
	return thenewBJM;
}
***********************************************************************************************************************************************/

  /******************************
   wrapper class for Invokable.
******************************/
  public class TerrBuilderWrapper {
    @InvocableVariable(label='Account ID')
    public ID accID2Align;

    @InvocableVariable(label='Accounts')
    public Account accs2Process;

    @InvocableVariable(label='Operation')
    public String operation;

    @InvocableVariable(label='Suggested TN')
    public String tns; //2019.06.06. needed by flow to validate alignment
  }
}