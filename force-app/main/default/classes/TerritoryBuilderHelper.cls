/***********************************************************************
this class is used to build the Queries for the TerritoryAllocator obj.
its methods are invoked from PB  builder via invokable method, however
the whole code is more suitable inside a trigger. PB execute after the
AFTER trigger so in order to updata record I have to clone it. Not nice.
***********************************************************************/
global class TerritoryBuilderHelper {
  @InvocableMethod(label='BuildSQL')
  /*******************************************************************
Invoked from PB on TerritoryAllocator obj
Force propagation and Validation not handled well in all branches.
Force propagation came only from in wave. We never set it manually
*******************************************************************/
  public static void buildWhereClauses(list<SQLBuilderWrapper> params) {
    String localSOQL;

    List<SQLBuilderWrapper> hubOnlyItems = new List<SQLBuilderWrapper>();
    /****************** unlikely to be called in batch ******************
	WRONG WRONG WRONG.  in case of  pro[agation it is called in batch and
	we can not guaranty if HUB and Nodes are not maixed.
	********************************************************************/
    List<TerritoryAllocator__c> tA2U = new List<TerritoryAllocator__c>();
    for (SQLBuilderWrapper bw : params) {
      //separate HUB from the rest
      if (bw.currentRecRT == 'HUB_BRANCH') {
        hubOnlyItems.add(bw);
        continue;
      }

      System.Debug('CSABAX aloc to process: ' + bw);
      TerritoryAllocator__c bw2u = bw.currentRecord.clone();
      bw2u.id = bw.currentRecord.id; //clone it because is post after trigger

      /*********** handle CUSTOM SPLITTED ************/
      if (bw.currentRecord.Type__c == 'CUSTOM_SPLITTED') {
        CreateSplitAllocator(bw2u);
        bw2u.Force_propagate__c = false;

        if (bw.currentRecord.Validate__c) {
          ValidateSOQL(bw2u);

          SetTerritoryTeam(bw2u);
          setTerrMarket(bw2u);
          setTerrSegment(bw2u);
        }

        tA2U.add(bw2u);

        continue;
      }
      /*********** handle CUSTOM SPLITTED ************/

      if (
        bw.currentRecord.Force_propagate__c == true &&
        bw.currentRecRT != 'HUB_ITEM'
      ) {
        //if this is a forced call no need to re-Calculate Local, just append it to Parent
        if (bw.currentRecord.Local_filter__c != null) {
          bw2u.Built_SOQL__c = bw.currentRecord.Local_filter__c;
        } else if (bw.currentRecRT == 'HUB') {
          bw2u.Built_SOQL__c = bw.currentRecord.Local_SOQL__c;
        }

        if (
          bw.parentAllocator != null &&
          bw.parentAllocator.Built_SOQL__c != null
        ) {
          bw2u.Built_SOQL__c =
            bw.parentAllocator.Built_SOQL__c +
            ' AND ' +
            bw2u.Built_SOQL__c;
        }

        bw2u.Force_propagate__c = false;
        if (bw2u.Validate__c == true) {
          bw2u.Validate__c = false;
        }

        TA2U.add(bw2u);
        continue;
      }

      /******************************** Calculate Local Query ****************************/
      localSOQL = MakeSOQL(bw.Fields, bw.Opp, bw.Values);
      if (localSOQL != null) {
        bw2u.Local_filter__c = localSOQL;

        if (
          bw.parentAllocator != null &&
          bw.currentRecRT != 'HUB_ITEM' &&
          bw.parentAllocator.Built_SOQL__c != null &&
          bw.parentAllocator.Built_SOQL__c != 'null' &&
          bw.parentAllocator.Built_SOQL__c.length() > 5
        ) {
          bw2u.Built_SOQL__c =
            bw.parentAllocator.Built_SOQL__c +
            ' AND ' +
            localSOQL;
        } else {
          bw2u.Built_SOQL__c = localSOQL;
        }

        /******************************** Calculate Local Query *************************/

        /************ Validate the localSOQL query and set Seg/Mar/Team *****************/
        if (bw.currentRecord.Validate__c) {
          ValidateSOQL(bw2u); //2019.06.26.

          SetTerritoryTeam(bw2u);
          setTerrMarket(bw2u);
          setTerrSegment(bw2u);
        } //end IF  validation
        /************ Validate the localSOQL query and set Seg/Mar/Team *****************/
      } else {
        //end if LocalQuery
        bw2u.Built_SOQL__c = bw.parentAllocator.Built_SOQL__c;
      }

      if (bw2u.Force_propagate__c == true) {
        bw2u.Force_propagate__c = false;
      }

      TA2U.add(bw2u);
    }

    if (hubOnlyItems.size() > 0) {
      buildHUBquery(hubOnlyItems);
    }

    if (TA2U.size() > 0) {
      update TA2U;
    }
  }

  /****************************************************************************
Try to  roll-Up splitted items into 1 single huge where clause
****************************************************************************/
  public static string createSplitAllocator(TerritoryAllocator__c alloc2Split) {
    List<TerritoryAllocatorItem__c> aItems = [
      SELECT
        Item_Value__c,
        Allocator__r.parentAllocator__r.Built_SOQL__c,
        Allocator__r.Force_propagate__c
      FROM TerritoryAllocatorItem__c
      WHERE
        Allocator__c = :alloc2Split.id
        AND Active__c = true
        AND Field__c = :alloc2Split.Account_field__c
      ORDER BY Item_Value__c
    ];

    if (aItems.size() == 0) {
      return null;
    }

    String parentSQL = null;
    String builtWhere = '( ';
    for (TerritoryAllocatorItem__c ai : aItems) {
      builtWhere = builtWhere + '\'' + ai.Item_Value__c + '\',';

      if (parentSQL == null) {
        parentSQL = ai.Allocator__r.parentAllocator__r.Built_SOQL__c;
      }
    }

    builtWhere = builtWhere.removeEnd(',');
    builtWhere = builtWhere + ' )';

    if (parentSQL != null) {
      alloc2Split.Built_SOQL__c =
        parentSQL +
        ' AND ' +
        alloc2Split.Account_field__c +
        ' IN ' +
        builtWhere;
    } else {
      alloc2Split.Built_SOQL__c =
        alloc2Split.Account_field__c +
        ' IN ' +
        builtWhere;
    }

    alloc2Split.Force_propagate__c = false;
    alloc2Split.validate__c = false;

    alloc2Split.Local_SOQL__c = builtWhere; //needed to validate splitted Node too

    /***** try to validate the Query ******/
    ValidateSOQL(Alloc2Split); //2019.06.26.

    return null;
  }
 
  /************************************************************************
   Collect HUBItems, create their Local Query and assemble them based on the
   HUB Advanced logic.
   At this stage the Item's SQL queries are already built so I just have to
   assemble them.
************************************************************************/
  public static List<string> buildHUBquery(list<SQLBuilderWrapper> params) {
    System.Debug(
      'CSABAX start BuildHUB_query with count params: ' + params.size()
    );
    List<String> retval = new List<String>();
    Set<Id> hubIds = new Set<Id>();
    for (SQLBuilderWrapper bw : params) {
      System.Debug('CSABAX alloc to process: ' + bw);
      HubIds.add(bw.currentRecord.id); //unlikely to have more then one. WE DO HAVE IN CASE OF  CASCADING
    }

    list<TerritoryAllocator__c> hubs2U = new List<TerritoryAllocator__c>();

    list<TerritoryAllocator__c> hubItems = [
      SELECT
        Id,
        Advanced_logic__c,
        Built_SOQL__c,
        parentAllocator__r.Built_SOQL__c,
        Force_propagate__c,
        isBottom__c,
        Territory_Name__c,
        TerritoryTeam__c,
        territory_Market__c,
        Segment__c,
        Geo__c,
        (
          SELECT Name, Local_filter__c
          FROM TerritoryAllocators__r
          WHERE RecordType.Name = 'HUB_ITEM'
        )
      FROM TerritoryAllocator__c
      WHERE id IN :HubIds
    ];

    for (TerritoryAllocator__c theHub : hubItems) {
      String advancedQ = theHub.Advanced_logic__c;
      List<TerritoryAllocator__c> itemList = theHub.TerritoryAllocators__r;
      for (TerritoryAllocator__c item : ItemList) {
        advancedQ = advancedQ.replace(item.Name, item.Local_filter__c);
      }

      TerritoryAllocator__c hub2u = theHub.clone();
      hub2u.id = theHub.id;

      if (
        hub2u.parentAllocator__c != null &&
        hub2u.parentAllocator__r.Built_SOQL__c != null
      ) {
        hub2u.Built_SOQL__c =
          hub2u.parentAllocator__r.Built_SOQL__c +
          ' AND ' +
          advancedQ;
      } else {
        hub2u.Built_SOQL__c = advancedQ;
      }

      hub2u.Local_SOQL__c = advancedQ;
      /******* validate the HUBs *******/
      ValidateSOQL(hub2u);

      //it might be possible that the HUB is a bottom one
      if (hub2U.isBottom__c == true) {
        SetTerritoryTeam(hub2U);
        setTerrMarket(hub2U);
        setTerrSegment(hub2U);
      }

      if (hub2U.Force_propagate__c == true) {
        hub2U.Force_propagate__c = false;
      }

      hubs2U.add(hub2u);
      retval.add(advancedQ);
    }

    if (Hubs2U.size() > 0) {
      Database.update(Hubs2U);
    }

    return retval;
  }

  /****************************************************
   check if the Where clause is a Valid SOQL statement.
****************************************************/
  public static String validateSOQL(String whereclause) {
    Integer retval;
    String sOQL = 'Select count() from Account where ' + Whereclause;
    try {
      retval = Database.countQuery(SOQL);
    } catch (Exception myex) {
      return myex.getMessage();
    }

    return 'VALID. ' + String.valueof(retval) + ' Accounts';
  }

  /************************************************************
   validate allocator built_SOQL and set Status fields.
************************************************************/
  public static void validateSOQL(TerritoryAllocator__c theA2A) {
    String validationResult = ValidateSOQL(theA2a.Built_SOQL__c);

    if (ValidationResult.startswith('VALID.')) {
      theA2A.SOQL_Status__c = 'Valid';
    } else {
      theA2A.SOQL_Status__c = 'Invalid';
    }

    theA2A.SQL_StatusResult__c = ValidationResult.left(100);
    theA2A.Validate__c = false;
  }

  /*****************************************************************************************

*****************************************************************************************/
  public static string buildEqualSOQL(
    String fields,
    String val,
    String fType,
    Boolean isNOT
  ) {
    String retval;
    String orAND = IsNOT == true ? 'AND' : 'OR';
    String eqNEQ = IsNOT == true ? '!=' : '=';

    List<String> fs = fields.split(';');
    for (String s : fs) {
      if (retval == null) {
        if (Ftype == 'STRING') {
          if (Val != 'NULL') {
            retval = s + ' ' + EQNEQ + ' \'' + Val + '\'';
          } else {
            retval = s + ' ' + EQNEQ + ' NULL ';
          }
        } else {
          retval = s + ' ' + EQNEQ + ' ' + Val;
        }
      } else {
        retval = retval + ' ' + orAND + ' ';

        if (Ftype == 'STRING') {
          retval = retval + ' ' + s + ' ' + EQNEQ + ' \'' + Val + '\'';
        } else {
          retval = retval + ' ' + s + ' ' + EQNEQ + ' ' + Val;
        }
      }
    }
    retval = '( ' + retval + ' )';

    return retval;
  }

  /**************************************************************************
   Assemble the 3 params into a valid SOQL query
   Field: TerritorySegment__c
   Opp:  IN
   Val:  val1,val2,val3,...,valX,valY
   retval = TerritorySegment__c in ('val1','val2','val3',....,'valY')
**************************************************************************/
  public static string build_IN_SOQL(String fields, String val, Boolean isNOT) {
    String retval;

    retval = Val.Replace(',', '\',\'');
    retval = '( \'' + retval + '\' )';

    retval = fields + ' IN ' + retval;
    if (ISNOT == true) {
      retval = '( NOT ' + retval + ' )';
    }

    return retval;
  }

  /***************************************************************************
   Assemble the 3 params into a valid SOQL query
   Field: TerritorySegment__c
   Opp:  BETWEEN
   Val:  val1;val2
   retval = TerritorySegment__c > val1 AND TerritorySegment__c < val2
*****************************************************************************/
  public static string build_BETWEEN_SOQL(
    String field,
    String vals,
    Boolean isNOT
  ) {
    String retval;
    List<String> range = Vals.split(';');
    if (range.size() == 2) {
      if (IsNOT == false) {
        retval =
          '( ' +
          field +
          ' > ' +
          range[0] +
          ' AND ' +
          field +
          ' < ' +
          range[1] +
          ' )';
      } else {
        retval =
          '( ' +
          field +
          ' < ' +
          range[0] +
          ' AND ' +
          field +
          ' > ' +
          range[1] +
          ' )';
      }

      return retval;
    }

    return retval;
  }

  /*******************************************************************************

*******************************************************************************/
  public static string build_GRELESS_SOQL(
    String field,
    String vals,
    Boolean isGRE
  ) {
    String retval;

    if (IsGRE == true) {
      retval = '( ' + field + ' > ' + Vals + ' )';
    } else {
      retval = '( ' + field + ' < ' + Vals + ' )';
    }

    return retval;
  }

  /*******************************************************************************

*******************************************************************************/
  public static string build_LIKE_SOQL(
    String field,
    String vals,
    String likeType
  ) {
    String retval;

    if (LikeType == 'STARTS_WITH') {
      retval = '( ' + field + ' Like \'' + Vals + '%\' )';
    } else if (LikeType == 'END_WITH') {
      retval = '( ' + field + ' Like \'%' + Vals + '\' )';
    } else if (LikeType == 'CONTAINS') {
      retval = '( ' + field + ' Like \'%' + Vals + '%\' )';
    } else if (LikeType == 'NOT_CONTAINS') {
      retval = '( NOT ' + field + ' Like \'%' + Vals + '%\' )';
    } else {
      retval = '( ' + field + ' Like \'%' + Vals + '%\' )';
    }

    return retval;
  }

  /********************************************************************
   intended to replace the above 2 methods.
********************************************************************/
  public static string build_IS_NOT_NULL_SOQL(String field, String opp) {
    String retval = '( ' + field + ' ' + opp + ' NULL )';
    return retval;
  }

  /**************************************************
   Get the SOAType of an Accout Field
**************************************************/
  public static String getFieldSOAType(String field) {
    Map<String, Schema.SObjectField> mapsof = Schema.SObjectType.Account.fields.getMap();
    Schema.SObjectField sof = mapsof.get(Field);
    if (sof == null) {
      return null;
    }

    Schema.DescribeFieldResult dr = sof.getDescribe();
    Schema.SOAPType soat = dr.getSOAPType();
    return string.valueof(soat);
  }

  /******************************************************************
   Assemble the 3 params into a valid SOQL query
   Field: TerritorySegment__c
   Opp:  EQUAL
   Val:  HIED
   retval = TerritorySegment__c = 'HIED'
******************************************************************/
  public static string makeSOQL(String field, String opp, String val) {
    String retval;
    if (Val != null) {
      Val = Val.remove('\'');
    }

    //we need to know the type of the Field(string/number/date/boolean)
    String ftype = getFieldSOAType(Field.split(';')[0]);

    switch on opp {
      when 'EQUAL' {
        retval = BuildEqualSOQL(Field, Val, Ftype, false);
      }
      when 'NOT_EQUAL' {
        retval = BuildEqualSOQL(Field, Val, Ftype, true);
      }
      when 'GREATER' {
        retval = Build_GRELESS_SOQL(Field, Val, true);
      }
      when 'LESS' {
        retval = Build_GRELESS_SOQL(Field, Val, false);
      }
      when 'STARTS_WITH' {
        retval = Build_LIKE_SOQL(Field, Val, opp);
      }
      when 'END_WITH' {
        retval = Build_LIKE_SOQL(Field, Val, opp);
      }
      when 'CONTAINS' {
        retval = Build_LIKE_SOQL(Field, Val, opp);
      }
      when 'NOT_CONTAINS' {
        retval = Build_LIKE_SOQL(Field, Val, opp);
      }
      when 'BETWEEN' {
        retval = Build_BETWEEN_SOQL(Field, Val, false);
      }
      when 'NOT_BETWEEN' {
        retval = Build_BETWEEN_SOQL(Field, Val, true);
      }
      when 'IN' {
        retval = Build_IN_SOQL(Field, Val, false);
      }
      when 'NOT_IN' {
        retval = Build_IN_SOQL(Field, Val, true);
      }
      when 'ISNULL' {
        //retval = Build_ISNULL_SOQL(Field);
        retval = Build_IS_NOT_NULL_SOQL(Field, '=');
      }
      when 'NOTNULL' {
        //retval = Build_NOTNULL_SOQL(Field);
        retval = Build_IS_NOT_NULL_SOQL(Field, '!=');
      }
      when else {
        return null;
      }
    }
    return retval;
  }

  /****************************************************************
Set Terr Team based on Territory Name. Call it only if is NULL.
Do not overwrite User's  selection.
****************************************************************/
  public static void setTerritoryTeam(TerritoryAllocator__c theTA) {
    //do this only  for Bottom
    if (theTA.isBottom__c != true || theTA.TerritoryTeam__c != null) {
      return;
    }

    /********************************* DEFINE THE TERRITORY TEAM STRINGS ******************************************/
    String nORAMHIEDEAST = 'NORAM HIED Southeast;NORAM HIED Mid Atlantic;NORAM HIED Northeast;NORAM HIED Canada;';
    String nORAMHIEDWEST = 'NORAM HIED South;NORAM HIED West Coast;';
    String nORAMHIEDCENTRAL = 'NORAM HIED Central;NORAM HIED Great Lakes;';

    String nORAMK12East = 'NORAM K12 Southeast;NORAM K12 Midatlantic;NORAM K12 Northeast;NORAM K12 Canada;';
    String nORAMK12West = 'NORAM K12 Northwest;NORAM K12 California;NORAM K12 Texas;';
    String nORAMK12Central = 'NORAM K12 Midwest;NORAM K12 SME West;NORAM K12 SME East;NORAM K12 Private;';

    String nORAMCORPENT = 'NORAM CORP Enterprise';

    String nORAMCORPMM1 = 'NORAM CORP FLORBAMA;NORAM CORP GEORGIA CAROLINA;NORAM CORP MIDWEST;NORAM CORP MOUNTAINWEST;NORAM CORP NCAL HAWAII;NORAM CORP NORTHWEST;NORAM CORP MIDATLANTIC;NORAM CORP SOCAL;NORAM CORP SOTEXLA;NORAM CORP LATAM;';
    String nORAMCORPMM2 = 'NORAM CORP CHI MICHIGAN;NORAM CORP NORTH TKA;NORAM CORP CHI SOUTH;NORAM CORP CHI NORTHWEST;NORAM CORP NORTHEAST;NORAM CORP NY METRO;NORAM CORP NJ UPNY;NORAM CORP OHINDI;NORAM CORP NEW ENGLAND;';
    String nORAMCORPSME1 = 'NORAM CORP SME WEST;NORAM CORP SME EAST;';

    String lATAMHIEDSpanish = 'LATAM EDU Spanish 1;LATAM EDU Spanish 2;LATAM EDU Mexico;';
    String lATAMHIEDBrazil = 'LATAM EDU Brazil 1;LATAM EDU Brazil 2;LATAM EDU Brazil 3;';

    String hIEDAUSNZ = 'APAC HIED AUSNZ 1;APAC HIED AUSNZ 2;';
    String hIEDASIA = 'APAC HIED ASIA 1;APAC HIED ASIA 2;';
    String k12AUSNZ = 'APAC K12 AUSNZ 1;APAC K12 AUSNZ 2;APAC K12 AUSNZ 3;APAC K12 AUSNZ 4;APAC K12/RTO AUSNZ 5;';
    String rTOAUSNZ = 'APAC RTO 1;APAC RTO 2;';
    String aPACCORP = 'APAC CORP 1;APAC CORP 2;APAC CORP 3;';
    /********************************* DEFINE THE TERRITORY TEAM STRINGS ******************************************/

    if (NORAMHIEDEAST.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'NORAM HIED EAST';
    }
    if (NORAMHIEDWEST.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'NORAM HIED WEST';
    }
    if (NORAMHIEDCENTRAL.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'NORAM HIED CENTRAL';
    }

    if (NORAMK12East.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'NORAM K12 East';
    }
    if (NORAMK12West.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'NORAM K12 West';
    }
    if (NORAMK12West.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'NORAM K12 West';
    }
    if (NORAMK12Central.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'NORAM K12 Central';
    }

    if (theTA.territory_Name__c.startswith('NORAM CORP Enterprise')) {
      theTA.TerritoryTeam__c = 'NORAM_CORP_ENT';
    }

    if (NORAMCORPMM1.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'NORAM CORP MM 1';
    }
    if (NORAMCORPMM2.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'NORAM CORP MM 2';
    }
    if (NORAMCORPSME1.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'NORAM CORP SME 1';
    }

    if (LATAMHIEDSpanish.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'LATAM HIED Spanish';
    }
    if (LATAMHIEDBrazil.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'LATAM HIED Brazil';
    }

    if (HIEDAUSNZ.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'HIED AUSNZ';
    }
    if (HIEDASIA.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'HIED ASIA';
    }
    if (K12AUSNZ.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'K12 AUSNZ';
    }
    if (RTOAUSNZ.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'RTO AUSNZ';
    }
    if (APACCORP.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'APAC CORP';
    }

    String eMEAEDUENT = 'EMEA EDU ENT UK/IRE 1;EMEA EDU ENT UK/IRE 2;EMEA EDU ENT NORDIC;EMEA EDU ENT DACH;EMEA EDU ENT BENELUX;EMEA EDU ENT IBERIA;EMEA EDU ENT EMERGING;';
    String eMEAEDUMMUK = 'EMEA EDU HIED MM UK;EMEA EDU MM RTO;EMEA EDU MM FE 1;EMEA EDU MM FE 2;EMEA EDU K12 MM UK;';
    String eMEAEDUMMBENONORD = 'EMEA EDU MM NORDIC;EMEA EDU MM BENODK;EMEA EDU MM SWEDEN;';
    String eMEAEDUMMEMERG = 'EMEA EDU ROW';
    String eMEAEDUINSIDE = 'EMEA EDU INSIDE';
    String eMEACORPENT1 = 'EMEA CORP ENT 1;EMEA CORP ENT 2;';
    String eMEACORPMM = 'EMEA CORP MM 1;EMEA CORP MM 2;';
    String eMEACORPIS = 'EMEA CORP IS 1';

    if (EMEAEDUENT.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'EMEA EDU ENT';
    }
    if (EMEAEDUMMUK.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'EMEA EDU MM UK';
    }
    if (EMEAEDUMMBENONORD.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'EMEA EDU MM BENONORD';
    }
    if (theTA.territory_Name__c == 'EMEA EDU ROW') {
      theTA.TerritoryTeam__c = 'EMEA EDU MM EMERG';
    }
    if (theTA.territory_Name__c.startswith('EMEA EDU INSIDE')) {
      theTA.TerritoryTeam__c = 'EMEA EDU INSIDE';
    } //2019.11.15.

    if (EMEACORPENT1.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'EMEA CORP ENT 1';
    }
    if (EMEACORPMM.contains(theTA.territory_Name__c + ';')) {
      theTA.TerritoryTeam__c = 'EMEA CORP MM';
    }
    if (theTA.territory_Name__c == 'EMEA CORP IS 1') {
      theTA.TerritoryTeam__c = 'EMEA CORP IS';
    }
  }

  /**************************************************************
   Set Terr Market.
**************************************************************/
  public static void setTerrMarket(TerritoryAllocator__c theTA) {
    if (theTA.isBottom__c == false) {
      return; //do this only  for Bottom
    }

    if (theTA.Geo__c == 'LATAM') {
      theTA.territory_Market__c = 'EDU';
    }

    if (
      theTA.Geo__c == 'APAC' &&
      (theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('CORP') ||
      (theTA.TerritoryTeam__c != null &&
      theTA.TerritoryTeam__c.contains('CORP')))
    ) {
      theTA.territory_Market__c = 'CORP';
    }

    if (
      (theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('HIED')) ||
      (theTA.TerritoryTeam__c != null &&
      theTA.TerritoryTeam__c.contains('HIED'))
    ) {
      theTA.territory_Market__c = 'EDU';
    }

    if (
      (theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('K12')) ||
      (theTA.TerritoryTeam__c != null && theTA.TerritoryTeam__c.contains('K12'))
    ) {
      theTA.territory_Market__c = 'EDU';
    }

    if (
      theTA.Geo__c == 'NORAM' &&
      ((theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('Enterprise')) ||
      (theTA.TerritoryTeam__c != null &&
      theTA.TerritoryTeam__c.contains('ENT')))
    ) {
      theTA.territory_Market__c = 'CORP';
    }

    if (
      theTA.Geo__c == 'NORAM' &&
      (theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('NORAM CORP ENT')) ||
      (theTA.TerritoryTeam__c != null &&
      (theTA.TerritoryTeam__c.contains('SME') ||
      theTA.TerritoryTeam__c.contains('MM')))
    ) {
      theTA.territory_Market__c = 'CORP';
    }

    if (
      (theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('RTO')) ||
      (theTA.TerritoryTeam__c != null && theTA.TerritoryTeam__c.contains('RTO'))
    ) {
      theTA.territory_Market__c = 'EDU';
    }

    if (
      theTA.TerritoryTeam__c != null &&
      (theTA.TerritoryTeam__c == 'EMEA EDU ENT' ||
      theTA.TerritoryTeam__c == 'EMEA EDU MM UK' ||
      theTA.TerritoryTeam__c == 'EMEA EDU MM EMERG' ||
      theTA.TerritoryTeam__c == 'EMEA EDU MM BENONORD' ||
      theTA.TerritoryTeam__c == 'EMEA EDU INSIDE')
    ) {
      theTA.territory_Market__c = 'EDU';
    }

    if (
      theTA.TerritoryTeam__c != null &&
      (theTA.TerritoryTeam__c == 'EMEA CORP ENT 1' ||
      theTA.TerritoryTeam__c == 'EMEA CORP MM' ||
      theTA.TerritoryTeam__c == 'EMEA CORP ENT 2' ||
      theTA.TerritoryTeam__c == 'EMEA CORP IS')
    ) {
      theTA.territory_Market__c = 'CORP';
    }
  }

  /**************************************************************
   Set Terr Tea based on TerrName and GEO
**************************************************************/
  public static void setTerrSegment(TerritoryAllocator__c theTA) {
    if (theTA.isBottom__c == false) {
      return; //do this only for Bottom
    }

    if (theTA.Geo__c == 'LATAM') {
      theTA.Segment__c = 'HIED';
    }

    if (
      theTA.Geo__c == 'APAC' &&
      ((theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('CORP')) ||
      (theTA.TerritoryTeam__c != null &&
      theTA.TerritoryTeam__c.contains('CORP')))
    ) {
      theTA.Segment__c = 'CORP';
      return;
    }

    if (
      theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('HIED') ||
      theTA.TerritoryTeam__c != null && theTA.TerritoryTeam__c.contains('HIED')
    ) {
      theTA.Segment__c = 'HIED';
      return;
    }

    if (
      theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('K12') ||
      theTA.TerritoryTeam__c != null && theTA.TerritoryTeam__c.contains('K12')
    ) {
      theTA.Segment__c = 'K12';
      return;
    }

    if (
      theTA.Geo__c == 'NORAM' &&
      ((theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('Enterprise')) ||
      (theTA.TerritoryTeam__c != null &&
      theTA.TerritoryTeam__c.contains('ENT')))
    ) {
      theTA.Segment__c = 'ENT';
      return;
    }

    if (
      theTA.Geo__c == 'NORAM' &&
      (theTA.TerritoryTeam__c != null &&
      (theTA.TerritoryTeam__c.contains('MM') ||
      theTA.TerritoryTeam__c.contains('SME')))
    ) {
      theTA.Segment__c = 'MM';
      return;
    }

    if (
      theTA.Geo__c == 'NORAM' &&
      theTA.TerritoryTeam__c != null &&
      theTA.TerritoryTeam__c.contains('NORAM CORP ENT')
    ) {
      theTA.Segment__c = 'ENT';
      return;
    }

    if (
      (theTA.territory_Name__c != null &&
      theTA.territory_Name__c.contains('RTO')) ||
      (theTA.TerritoryTeam__c != null && theTA.TerritoryTeam__c.contains('RTO'))
    ) {
      theTA.Segment__c = 'RTO';
      return;
    }

    //INCLUDE EMEA rule here too
    if (theTA.TerritoryTeam__c == 'EMEA EDU ENT') {
      theTA.Segment__c = 'ENT';
    }
    if (
      theTA.TerritoryTeam__c == 'EMEA EDU MM UK' ||
      theTA.TerritoryTeam__c == 'EMEA EDU MM BENONORD' ||
      theTA.TerritoryTeam__c == 'EMEA EDU MM EMERG' ||
      theTA.TerritoryTeam__c == 'EMEA EDU INSIDE'
    ) {
      theTA.Segment__c = 'MM';
    }
    if (
      theTA.TerritoryTeam__c == 'EMEA CORP ENT 1' ||
      theTA.TerritoryTeam__c == 'EMEA CORP MM'
    ) {
      theTA.Segment__c = 'ENT 1';
    }
    if (theTA.TerritoryTeam__c == 'EMEA CORP ENT 2') {
      theTA.Segment__c = 'ENT 2';
    }
    if (theTA.TerritoryTeam__c == 'EMEA CORP IS') {
      theTA.Segment__c = 'IS';
    }
  }

  /***********************************************************************************************/
  /***********************************************************************************************/

  public class SQLBuilderWrapper {
    @InvocableVariable(label='Account field')
    public String fields;

    @InvocableVariable(label='Operator')
    public String opp;

    @InvocableVariable(label='Values')
    public String values;

    @InvocableVariable(label='Parent SOQL')
    public String parentSQL;

    @InvocableVariable(label='ParentSQL')
    public TerritoryAllocator__c parentAllocator;

    @InvocableVariable(label='currentRec')
    public TerritoryAllocator__c currentRecord;

    @InvocableVariable(label='currentRec RT')
    public String currentRecRT; //2019.05.27.

    /*********************************************
   if this parameter is passed we call alignment
   This is possible when method is invoked from
   within an Account PB
*********************************************/
    @InvocableVariable(label='AccountID to Align')
    public ID accountID2Align;
  }
}