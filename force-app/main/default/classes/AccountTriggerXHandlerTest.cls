@istest
public class AccountTriggerXHandlerTest {

	@testsetup
	private static void setup() {
		List<System_Country_Validation_Record__c> countries = new List<System_Country_Validation_Record__c>();
		countries.add(new System_Country_Validation_Record__c(Name = 'United States', Country_Code__c='US', Region__c='DOMESTIC'));
		countries.add(new System_Country_Validation_Record__c(Name = 'United Kingdom', Country_Code__c='GB', Region__c='EMEA'));
		insert countries;  
	}
	
	@istest
	private static void testAccounInsertAndUpdate() {
		Account testAccount = (Account) TestFactory.createsObject(new Account());
		testAccount.BillingCountryCode = 'US';
		insert testAccount;

		testAccount = [Select Customer_Success_Region__c from Account where id = :testAccount.Id];
		System.assertEquals('Domestic', testAccount.Customer_Success_Region__c, 'When country is US, region should be domestic.');

		testAccount.BillingCountryCode = 'GB';
		update testAccount;
		testAccount = [Select Customer_Success_Region__c from Account where id = :testAccount.Id];
		System.assertEquals('EMEA', testAccount.Customer_Success_Region__c, 'When country changes, region should be updated.');

		testAccount.Customer_Success_Region__c = 'Domestic';
		update testAccount;
		testAccount = [Select Customer_Success_Region__c from Account where id = :testAccount.Id];
		System.assertEquals('Domestic', testAccount.Customer_Success_Region__c, 'Should be able to manually change region.');
	}

/********************************************
collect all countries from the BillingCountry
picklist, create Accounts then check Regions.
********************************************/
@istest
private static void testAccountCountryName() 
	{
		List<Account> newAccs =  new List<Account>();
		List<System_Country_Validation_Record__c> countries = new List<System_Country_Validation_Record__c>();

		Schema.DescribeFieldResult fieldResult = Account.BillingCountryCode.getDescribe();
		List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
		Integer ccounter = 0;
		Map<String,String> mapcountry2region = new map<String,String>();      //store the expected Region per country
		Map<String,String> mapcountryName2Code = new map<String,String>(); 
		List<String> geos = new List<String>{'APAC','LATAM','EMEA','Domestic'};
		for( Schema.PicklistEntry pickListVal : ple)
        {
			if(pickListVal.getValue() == 'US' || pickListVal.getValue() == 'GB') { continue; } //created in testsetup
			System.Debug('CSABA_X building Acc and country  for '+ pickListVal.getValue());
            String theReqion = geos[math.mod(ccounter,4)];              //distribute them randomly among new Accounts
		    countries.add(new System_Country_Validation_Record__c(Name = pickListVal.getLabel(), Country_Code__c = pickListVal.getValue(), Region__c = theReqion));
            mapcountry2region.put(pickListVal.getLabel(),theReqion);
			mapcountryName2Code.put(pickListVal.getLabel(),pickListVal.getValue());

			Account testA = new Account(Name='TEST_ACC4Region_' + String.valueof(ccounter));
			testA.BillingCountry = pickListVal.getLabel();
            newAccs.add(testA);

		    ccounter++;
			if(ccounter == 10)  { break; } //otherwise we hit CPU Limit 
		} 

	    Database.insert(countries);	
 		for(System_Country_Validation_Record__c theNewC :countries)
		   {  
			System.Debug('CSABA_Y check SCVR: ' + theNewC);   
			System.assertNotEquals(NULL, theNewC.id,theNewC);
		   }         

		Database.insert(newAccs);
        Set<ID> accIds = new Set<ID>();
		for(Account theNewA :newAccs)
		   {
			System.Debug('CSABA_W checking new Acc : ' +  theNewA);   
			System.assertNotEquals(NULL, theNewA.id,theNewA);
			accIds.add(theNewA.id);
		   }

        newAccs = [Select id, Name,Billing_Country__c,BillingCountry,BillingCountryCode,Customer_Success_Region__c,TerritoryGeo__c from Account where id in :accIds];
		for(Integer i = 0; i < newAccs.size(); i++)  
		{	
		System.assertEquals(mapcountry2region.get(newAccs[i].BillingCountry),newAccs[i].Customer_Success_Region__c,newAccs[i]);
		System.debug('CSABA_BEFORE_SWAP: N/C =' + newAccs[i].BillingCountry + '/' +  newAccs[i].BillingCountryCode);
		newAccs[i].BillingCountry = countries[newAccs.size() - 1 - i].Name; //Just swap the Billing Countries among accounts and update them
		newAccs[i].BillingCountryCode = mapcountryName2Code.get(newAccs[i].BillingCountry); //to keep Name and Code in sync in BU trigger 
		System.debug('CSABA_AFTER_SWAP: N/C =' + newAccs[i].BillingCountry + '/' +  newAccs[i].BillingCountryCode);
		} 

		update newAccs; //test update too
        newAccs = [Select id, Name,Billing_Country__c,BillingCountry,BillingCountryCode,Customer_Success_Region__c,TerritoryGeo__c from Account where id in :accIds];
		for(Integer i = 0; i < newAccs.size(); i++)  
		{	
		System.debug('CSABA_AFTER_SWAP_UPDATE: N/C =' + newAccs[i].BillingCountry + '/' +  newAccs[i].BillingCountryCode);			
		System.assertEquals(mapcountry2region.get(newAccs[i].BillingCountry),newAccs[i].Customer_Success_Region__c,newAccs[i]);
        newAccs[i].BillingCountry = NULL;  //clear the Country and expect Cleared CSR
        newAccs[i].BillingCountryCode = NULL;		
		} 

		update newAccs; //test update too
        newAccs = [Select id, Name,Billing_Country__c,BillingCountry,BillingCountryCode,Customer_Success_Region__c,TerritoryGeo__c from Account where id in :accIds];
		for(Integer i = 0; i < newAccs.size(); i++)  
		{	
		System.debug('CSABA_AFTER_SWAP_UPDATE_CLEAR: N/C =' + newAccs[i].BillingCountry + '/' +  newAccs[i].BillingCountryCode);				
		System.assertEquals(NULL,newAccs[i].BillingCountryCode,newAccs[i]);			
		System.assertEquals(NULL,newAccs[i].Customer_Success_Region__c,newAccs[i]);
        newAccs[i].BillingCountry = countries[i].Name;
		} 


        
		delete countries;  //delete countries to simulate no match for CSR
		update newAccs;
        newAccs = [Select id, Name,Billing_Country__c,BillingCountry,BillingCountryCode,Customer_Success_Region__c,TerritoryGeo__c from Account where id = :newAccs[0].id];
		for(Integer i = 0; i < newAccs.size(); i++)  
		{	
		System.debug('CSABA_AFTER_DELETE_C: N/C =' + newAccs[i].BillingCountry + '/' +  newAccs[i].BillingCountryCode);				
		System.assertEquals(NULL,newAccs[i].Customer_Success_Region__c,newAccs[i]);
		}		

	}	


}