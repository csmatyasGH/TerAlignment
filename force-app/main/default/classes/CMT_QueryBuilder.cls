/*****************************************
Build SOQL Select/Where statemens based on
data from CustomMetadatatype
AQO_filterBuilder__mdt
AQO_filterItems__mdt

USe case. Inject query locator filter into
batch classes to control data volume
*****************************************/
global  class CMT_QueryBuilder 
{

    public static String buildSOQLfromCMT(String cmtbuilderName)
    {
        String retval;
        List<SOQL_Builder__mdt> objSOQLB = [SELECT DeveloperName,ObjectName__c,Field_List__c
                                             ,(SELECT id,ObjectName__c,FieldName__r.QualifiedAPIName,itemType__c,Operator__c,Item_Value__c,item_order__c 
                                               FROM SOQLBuilderItems__r  ORDER BY itemType__c,ObjectName__c,item_order__c ASC
                                              ) 
                                              FROM SOQL_Builder__mdt
                                              WHERE DeveloperName = :cmtbuilderName
                                            ];

        Map<String,String> mapObj2Fields2Query = new Map<String,String>(); //a map where the values is a list of Field APIs ("Id,Name,Type")
        Map<String,String> mapObj2GroupBy = new Map<String,String>(); 
        Map<String,String> mapObj2OrderBy = new Map<String,String>();          
        Map<String,String> mapObj2Limit = new Map<String,String>();    
        Map<String,String> mapObj2WhereAL = new Map<String,String>();    
        Map<String,String> mapObj2HavingAL = new Map<String,String>();                            
        Map<String,List<String>> mapObj2WhereParams = new Map<String,List<String>>();   
        Map<String,List<String>> mapObj2HavingParams = new Map<String,List<String>>();    
        string limitq; 
        
        if(ObjSOQLB.size() == 0 || ObjSOQLB.size() > 1)
          {   
          return retval;    
          }   
        
        list<SOQL_Builder_Item__mdt> itemlist = ObjSOQLB[0].SOQLBuilderItems__r;
        if(itemlist.size() == 0)
          {              
          return retval;    
          }   
      
        String mainObjectName = ObjSOQLB[0].ObjectName__c;  
        
        //distribute the items in maps for each object involved 
        for(SOQL_Builder_Item__mdt item :itemlist)
           {
            //pass each CustomField ID  into the  set
            String theFN = item.FieldName__r.QualifiedAPIName;

            if(item.itemType__c == 'QueryField') 
              {
              putIteminMap(mapObj2Fields2Query,item.ObjectName__c,theFN); 
              }            
            else if(item.itemType__c == 'WhereClause')  
              {
              //before putting it into the map build HERE
              String filterValue = item.Item_Value__c;
              if(theFN != NULL  && item.Operator__c != NULL)
              {
              filterValue = TerritoryBuilderHelper.makeSOQL(theFN, item.Operator__c, item.Item_Value__c);  
              }

              putItemsinMap(mapObj2WhereParams,item.ObjectName__c,filterValue);                
              }  
            else if(item.itemType__c == 'GroupBy') 
              {
              putIteminMap(mapObj2GroupBy,item.ObjectName__c,theFN);
              }   
              else if(item.itemType__c == 'Having') 
              {
                putItemsinMap(mapObj2havingParams,item.ObjectName__c,item.Item_Value__c);
              }
              else if(item.itemType__c == 'Order by') 
              {
                putIteminMap(mapObj2OrderBy,item.ObjectName__c,theFN);
              }
              else if(item.itemType__c == 'Advanced Where Logic') 
              { //we could have only  1/object
                mapObj2WhereAL.put(item.ObjectName__c,item.Item_Value__c);
              }  
              else if(item.itemType__c == 'Advanced Having Logic') 
              { //we could have only  1/object
                mapObj2HavingAL.put(item.ObjectName__c,item.Item_Value__c);
              }                           
              else if(item.itemType__c == 'Limit') 
              {
                limitq = item.Item_Value__c;
              }              
           }
 
        String mainObjQuery;
        List<String> innerQueryes =  new List<String>();
        //for each object build the SOQL then assemble them;
        for(String oname :mapObj2Fields2Query.keySet())
            {   
            //put the below in a separate method and handle having too   
            List<String> whereparams = mapObj2WhereParams.get(oname);           
            String advLogic = mapObj2WhereAL.get(oname);
            String wc;
            if(whereparams != NULL)
              {
                if(whereparams.size() > 1 && advLogic != NULL)
                {
                wc = String.format(advLogic,whereparams);    
                }
                if(whereparams.size() == 1)
                {
                wc = whereparams[0];    
                } 
              }

            String theSOQL = assembleSOQL(oname,mapObj2Fields2Query.get(oname),wc,mapObj2GroupBy.get(oname),NULL,limitq);  
            if(oname != mainObjectName)
              {
              innerQueryes.add(theSOQL); 
              }
            else 
              {
              mainObjQuery = theSOQL; 
              }  
            }

        //if exists parse the inner queries into main object query 
        if(innerQueryes == NULL  || innerQueryes.size() == 0)
        {
        return mainObjQuery;
        }
        
        integer indexofFrom = mainObjQuery.indexOf('from');
        String mqLeft = mainObjQuery.left(indexofFrom);
        String mqRight = mainObjQuery.substring(indexofFrom); 
        for(String innerQ :innerQueryes)
            {
            retval = mqLeft + ',(' +  innerQ + ') ';
            }
        retval = retval + mqRight;    
        return retval;                                         
    }

    /***************************************************************************************
     * 
    ***************************************************************************************/
    private static void putIteminMap(Map<String,String> themap, String objName,String theFN)
    {
      String fields = themap.get(objName);
      if(fields == NULL)
         {
           fields = theFN;
         }
       else 
         {
           fields = fields + ',' + theFN;  
         }
         themap.put(objName,fields);      
    }

    /**********************************************************************************************
     * 
    **********************************************************************************************/
    @testvisible
    private static void putItemsinMap(Map<String,List<String>> themap, String objName,String theFN)
    {
      List<String> Params = themap.get(objName);
      if(Params == NULL)
         {
          Params = new List<String>();
         }
         Params.add(theFN); //item value shuld be first build like I did in Terr Builder   
      themap.put(objName,Params);    
    }    

    /***********************************************************************************************************************************************
      
    ***********************************************************************************************************************************************/
    @testvisible
    private static String assembleSOQL(String ObjName, String QueryfieldList,String whereClause,String groupBy, String havingClause,String thelimit)
    { 
     String retval; //'Select ';
     if(objName == NULL || QueryfieldList == NULL)
       {
       return retval;    
       } 
     
    retval = 'Select ' + QueryfieldList + ' from ' + ObjName;

    if(whereClause != NULL)
       {
       retval =  retval + ' WHERE ' + whereClause;    
       }

    if(groupBy != NULL)
       {
        retval =  retval + ' GROUP BY ' +  groupBy; 
        if(havingClause != NULL)
           {
           retval = retval + ' HAVING ' + havingClause;    
           }  
       }  

       if(thelimit != NULL)
       {
       retval =  retval + ' LIMIT ' + thelimit;    
       }       
     
     return retval;
    }



    /***************************************************************
    get the WHERE cluse part from the Custom Metadata type
    ***************************************************************/
    public static string getCustomSettingWhereFilter(String objName) {
        String retval;
        List<AQO_filterBuilder__mdt> oppfilter = [
          SELECT Id,AdvancedLogic__c, DeveloperName,
          (SELECT id,itemValue__c FROM AQO_filterItems__r where itemType__c = 'WhereClause' ORDER BY itemOrder__c ASC) 
          FROM AQO_filterBuilder__mdt
          WHERE DeveloperName = :objName
        ];
        System.Debug('CSABAX we have Oppfilter size = ' +  Oppfilter.size()); 
        for (AQO_filterBuilder__mdt cmt : Oppfilter) 
        {
          String advLogic = 'WHERE ' + cmt.AdvancedLogic__c;
          List<String> parameters = new List<String>();
          System.debug('CSABA be have items = ' + cmt.AQO_filterItems__r);
          for (AQO_filterItems__mdt item : cmt.AQO_filterItems__r) 
          {
            parameters.add(item.itemValue__c);
          }
    
          retval = String.format(advLogic, parameters);
        }
        System.Debug('CSABA getCustomSettingAQOFilter retal = ' + retval);
        return retval;
      }    

}