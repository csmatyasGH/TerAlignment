/****************************************************************
IT WILL NOT BE USED AS QUEUEABLE WE CAN REMOVE THIS FROM CLASS
Will be called from batchProcessAccountTerritory to find Match.
Also will be called from AccountTerritoryNameBuilder by invokable
****************************************************************/
public without sharing class AccountTerrNameBuilderQueueable { //implements Queueable
  public static map<String, List<TerritoryAllocator__c>> mapBranch2AlocList;
  public static map<ID, TerritoryAllocator__c> mapAlocId2ParentAlloc;
  public static map<ID, TerritoryAllocator__c> mapAlocId2Alloc;

  /******************************************
   Collect ALL Allocators, Bottom or NOT and
   build a map for GEO to List of Bottom
   allocators and 1 map for all AllocatorIDs
   to its Parent Allocator
******************************************/
  public static void buildMaps(String theGEO) {
    mapBranch2AlocList = new Map<String, List<TerritoryAllocator__c>>();
    mapAlocId2ParentAlloc = new Map<ID, TerritoryAllocator__c>();
    mapAlocId2Alloc = new Map<ID, TerritoryAllocator__c>();

    List<TerritoryAllocator__c> allocator2Iterate = [
      SELECT
        ID,
        Name,
        Built_SOQL__c,
        Geo__c,
        BranchType__c,
        Type__c,
        Territory_Name__c,
        RecordType.Name,
        isBottom__c,
        Local_SOQL__c,
        Account_field__c,
        Operator__c,
        Comparison_Value__c,
        Level__c,
        Advanced_logic__c,
        ParentAllocator__c,
        ParentAllocator__r.RecordType.Name,
        ParentAllocator__r.Name,
        ParentAllocator__r.Level__c,
        ParentAllocator__r.Type__c,
        ParentAllocator__r.Account_field__c,
        ParentAllocator__r.Operator__c,
        ParentAllocator__r.Comparison_Value__c,
        ParentAllocator__r.Advanced_logic__c,
        Order_of_Execution__c,
        Local_filter__c,
        TerritoryTeam__c,
        Territory_Market__c,
        Segment__c,
        (
          SELECT Id, Name, Account_field__c, Operator__c, Comparison_Value__c
          FROM TerritoryAllocators__r
          WHERE RecordType.Name = 'HUB_ITEM'
        )
      FROM TerritoryAllocator__c
      WHERE
        Active__c = true
        AND Geo__c = :theGEO
        AND RecordType.Name != 'HUB_ITEM'
      ORDER BY Order_of_Execution__c ASC
    ];

    /***********************************************************************************************
	   Build a map of String to AT Lists and map where key = AllocatorID and the Value = ParentAlloctor
	***********************************************************************************************/
    for (TerritoryAllocator__c theAT : allocator2Iterate) {
      mapAlocId2Alloc.put(theAT.id, theAT);

      if (theAT.isBottom__c == false) {
        continue;
      } //store only the bottom Node

      String bt = theAT.Geo__c;

      if (mapBranch2AlocList.get(bt) == null) {
        List<TerritoryAllocator__c> theATL = new List<TerritoryAllocator__c>();
        theATL.add(theAT);
        mapBranch2AlocList.put(BT, theATL);
      } else {
        mapBranch2AlocList.get(BT).add(theAT);
      }
    }

    for (
      TerritoryAllocator__c at : allocator2Iterate //in this way we will be able to match HUBs but introduce a new loop.
    ) {
      if (at.ParentAllocator__r != null) {
        mapAlocId2ParentAlloc.put(
          at.id,
          mapAlocId2Alloc.get(at.ParentAllocator__c)
        );
      }
    }
  }

  /**************************************************************
   its constructor will never be called. we use its static methods
**************************************************************/
  public AccountTerrNameBuilderQueueable(List<Account> acc2Check) {
    buildMaps(acc2Check[0].TerritoryGeo__c);
  }

  /****************************************************************************
   check if the Account passed as param1 matching the Condition of the Allocator
****************************************************************************/
  @testVisible
  private static Boolean matchingNode(
    Account theA2M,
    TerritoryAllocator__c ta
  ) {
    Boolean retval = false;

    Object val = theA2M.get(ta.Account_field__c);
    switch on TA.Operator__c {
      when 'EQUAL' {
        if (val == null) {
          if (ta.Comparison_Value__c != 'NULL')
            return false;
          else
            return true;
        }
        return String.valueof(val) == ta.Comparison_Value__c;
      }
      when 'NOT_EQUAL' {
        if (val == null) {
          if (ta.Comparison_Value__c != 'NULL')
            return true;
          else
            return false;
        }
        return String.valueof(val) != ta.Comparison_Value__c;
      }
      when 'GREATER' {
        if (val == null)
          return false;
        return Double.valueof(val) > Double.valueof(ta.Comparison_Value__c);
      }
      when 'LESS' {
        if (val == null)
          return false;
        return Double.valueof(val) < Double.valueof(ta.Comparison_Value__c);
      }
      when 'STARTS_WITH' {
        if (val == null)
          return false;
        return String.valueof(val).startswith(ta.Comparison_Value__c);
      }
      when 'END_WITH' {
        if (val == null)
          return false;
        return String.valueof(val).endsWith(ta.Comparison_Value__c);
      }
      when 'CONTAINS' {
        if (val == null)
          return false;
        return String.valueof(val).contains(ta.Comparison_Value__c);
      }
      when 'NOT_CONTAINS' {
        if (val == null)
          return true;
        return !String.valueof(val).contains(ta.Comparison_Value__c);
      }
      when 'BETWEEN' {
        if (val == null)
          return false;
        String[] rangele = TA.Comparison_Value__c.split(';');
        String v1 = rangele[0];
        String v2 = rangele[1];
        retval =
          Double.valueof(val) > Double.valueOf(v1) &&
          Double.valueof(val) < Double.valueof(v2);
        return retval;
      }
      when 'NOT_BETWEEN' {
        if (val == null)
          return false;
        String[] rangele = TA.Comparison_Value__c.split(';');
        String v1 = rangele[0];
        String v2 = rangele[1];
        retval =
          Double.valueof(val) < Double.valueof(v1) ||
          Double.valueof(val) > Double.valueof(v2);
        return retval;
      }
      when 'IN' {
        if (val == null)
          return false;
        String val2comp = String.valueof(val);
        Boolean compres =
          ta.Comparison_Value__c == val2comp ||
          ta.Comparison_Value__c.startswith(val2comp + ',') ||
          ta.Comparison_Value__c.endswith(',' + val2comp) ||
          ta.Comparison_Value__c.contains(',' + val2comp + ',');
        return compres;
      }
      when 'NOT_IN' {
        if (val == null)
          return true;
        //this has a leak in case of substring match 'Sao Paulo' vs 'val1,Greather Sao Paolo,val2'
        String val2comp = String.valueof(val);
        Boolean compres =
          ta.Comparison_Value__c != val2comp &&
          ta.Comparison_Value__c.startswith(val2comp + ',') == false &&
          ta.Comparison_Value__c.endswith(',' + val2comp) == false &&
          ta.Comparison_Value__c.contains(',' + val2comp + ',') == false;
        return ta.Comparison_Value__c.contains(String.valueof(val)) == false;
      }
      when 'ISNULL' {
        return val == null ? true : false;
      }
      when 'NOTNULL' {
        return val == null ? false : true;
      }
      when else {
        return false;
      }
    } //end switch
  }

/***************************************************************************
Collect Node Items and validate tham as NODe and call BooleanEval function.
***************************************************************************/
  @testVisible
  private static Boolean matchingHUB(Account theA2M, TerritoryAllocator__c ta) {
    Boolean retval = false;

    String advLogicStr = ta.Advanced_logic__c;
    for (TerritoryAllocator__c theHI : ta.TerritoryAllocators__r) {
      Boolean nodematchRes = matchingNode(theA2M, theHI);
      AdvLogicStr = AdvLogicStr.replace(
        theHI.Name,
        String.valueof(nodematchRes)
      );
    }

    retval = BooleanExpression.eval(advLogicStr.toUpperCase());

    return retval;
  }

  /************************************************************************************
   the patter to be match is like ShippingPostalCode4Terr__c in (val1,val2,........valN)
************************************************************************************/
  @testVisible
  private static Boolean matchingSplittedNode(
    Account theA2M,
    TerritoryAllocator__c ta
  ) {
    Boolean retval = false;
    Object val = theA2M.get(ta.Account_field__c);

    if (val == null) {
      return retval;
    }

    if (ta.Local_SOQL__c == null) {
      return retval;
    }

    return ta.Local_SOQL__c.contains(String.valueof(val));
  }

  /**************************************************************************************************
iterate through the TerritoryAllocators starting from the BOTTOM one and go up on the hierarchy.
For each record  all CheckNode/Hub
**************************************************************************************************/
  public static TerritoryAllocator__c findTerritoryName4Account(
    Account account2MAtch,
    Boolean isPilot
  ) {
    TerritoryAllocator__c retval;

    if (mapBranch2AlocList == null) {
      buildMaps(Account2MAtch.TerritoryGeo__c);
    }
    if (mapBranch2AlocList == null) {
      return retval;
    }

    String accountTerrBranch = account2MAtch.TerritoryGeo__c;

    List<TerritoryAllocator__c> aTList4BranchType = mapBranch2AlocList.get(
      accountTerrBranch
    );
    if (aTList4BranchType == null) {
      return null;
    }

    TerritoryAllocator__c alloc2match;
    for (TerritoryAllocator__c theTA : aTList4BranchType) {
      Boolean hasMatch;
      alloc2match = theTA;
      do {
        if (theTA.Type__c == 'CUSTOM_SPLITTED' && alloc2match == theTA) {
          hasMatch = matchingSplittedNode(Account2MAtch, alloc2match);
        } else if (alloc2match.RecordType.Name == 'HUB') {
          hasMatch = matchingHUB(Account2MAtch, alloc2match);
        } else if (alloc2match.RecordType.Name == 'NODE') {
          hasMatch = matchingNode(Account2MAtch, alloc2match);
        }

        if (hasMatch == false) {
          break;
        }

        alloc2match = mapAlocId2ParentAlloc.get(alloc2match.id);
      } while (alloc2match != null);

      if (hasMatch == false) {
        continue;
      } //get another Bottom allocator

      //if we are here Account match the node and its parent condition. We should check each field: TerrName, Team, Segment, Market
      //and mark account for update only if at least 1 field has changed
      if (
        account2MAtch.TerritoryName__c != theTA.Territory_Name__c ||
        account2MAtch.TerritoryTeam__c != theTA.TerritoryTeam__c ||
        account2MAtch.TerritoryMarket__c != theTA.Territory_Market__c ||
        account2MAtch.TerritorySegment__c != theTA.Segment__c ||
        account2MAtch.TerritoryName_Suggested__c != theTA.Territory_Name__c
      ) {
        if (account2MAtch.FreezeAlignment__c == false) {
          account2MAtch.Need_Alignment__c = true; //this does not necesarilly mean Need Alignment. Its just Need Update
        }

        if (
          account2MAtch.TerritoryName_Suggested__c != theTA.Territory_Name__c
        ) {
          account2MAtch.TerritoryName_Suggested__c = theTA.Territory_Name__c;
        }

        if (isPilot == false) {
          //I think this should be removed because is done at Freeze stage and is done in the QuickAction/Flow too
          //at the other hand since we no longer use Segment/Market directly in rules we can set this all the time
          account2MAtch.TerritoryName__c = theTA.Territory_Name__c; //if we do this we do no longer have PILOT!
          //account2MAtch.TerritoryTeam__c = theTA.TerritoryTeam__c;
          //account2MAtch.TerritoryMarket__c = theTA.Territory_Market__c;
          //if(account2MAtch.TerritoryGeo__c != 'EMEA' ) {account2MAtch.TerritorySegment__c = theTA.Segment__c; }
        }

        //we do not pass this value before the FREEZE stage. save them for that time in a temp_AllocatorID__c field  T=xx/M=yy/S=zz
        account2MAtch.temp_AllocatorID__c =
          '' +
          theTA.TerritoryTeam__c +
          '/' +
          theTA.Territory_Market__c +
          '/' +
          theTA.Segment__c;
      }
      retval = theTA;
      break;
    } //end TA for loop

    return retval;
  }
}