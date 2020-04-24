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
}