public with sharing class AccountTriggerXHandler extends TriggerX {
  public override void onBeforeInsert() {
    for (Account acct : (List<Account>) records) {
      acct.Customer_Success_Region__c = countryToRegionMap.get(
        acct.BillingCountryCode
      );

      if (acct.Customer_Success_Region__c == null) {
        acct.Customer_Success_Region__c = countryToRegionMap.get(
          acct.BillingCountry
        );
      }

      //territory alignment related changes.
      if (acct.TerritoryGeo__c == null) {
        SetGeo(acct);
      }

      AccountTerritoryNameBuilder.enrichAccounts(acct, null);
      //territory alignment related changes.
    }
  }

  public override void onBeforeUpdate(Map<Id, sObject> triggerOldMap) {
    //find those accounts where the Billing Country Code OR
    //BillingCountryCode has changed, and update the region

    String[] fields2trach = new List<String>{};
    fields2trach.add('BillingCountryCode');
    fields2trach.add('BillingCountry');
    for (Account acct : (List<Account>) records) {
      String[] changedFields = getChangedFields(
        fields2trach,
        acct,
        triggerOldMap.get(acct.Id)
      );

      if (
        changedFields.contains('BillingCountryCode') ||
        acct.Customer_Success_Region__c == null
      ) {
        acct.Customer_Success_Region__c = countryToRegionMap.get(
          acct.BillingCountryCode
        );
      } else if (
        changedFields.contains('BillingCountry') ||
        acct.Customer_Success_Region__c == null
      ) {
        acct.Customer_Success_Region__c = countryToRegionMap.get(
          acct.BillingCountry
        );
      }

      //territory alignment related changes.
      if (
        acct.TerritoryGeo__c == null ||
        TriggerX.hasChangedFields(
          new List<sObjectField>{
            Account.Top_Parent_Billing_Country__c,
            Account.ShippingCountry,
            Account.ShippingCountryCode
          },
          acct,
          triggerOldMap.get(acct.Id)
        )
      ) {
        SetGeo(acct);
      }

      AccountTerritoryNameBuilder.EnrichAccounts(
        acct,
        (Account) triggerOldMap.get(acct.Id)
      );
      //territory alignment related changes.
    }
  }

/********************************

********************************/
  private void setGeo(Account acct) {
    //2019.11.20. String geou = countryToRegionMap.get(acct.Top_Parent_Billing_Country__c);
    String geou = countryToRegionMap.get(acct.ShippingCountry); //above was overruled

    if (geou == 'Domestic') {
      acct.TerritoryGeo__c = 'NORAM';
    } else if (
      geou == 'LATAM' &&
      (acct.Org_Type__c == 'Corporate' ||
      acct.Org_Type__c == 'Corp' ||
      acct.Org_Type__c == 'Government') &&
      (acct.Primary_Business__c != 'Higher Ed' &&
      acct.Primary_Business__c != 'K12' &&
      acct.Primary_Business__c != 'Further Education' &&
      acct.Primary_Business__c != 'RTO/Training')
    ) {
      //2019.08.21. new changes from Sagar 'Primary_Business__c' not in ["Higher Ed","K12","Further Education","RTO/Training"]
      acct.TerritoryGeo__c = 'NORAM';
    } else {
      acct.TerritoryGeo__c = geou;
    }
  }

  private Map<String, String> countryToRegionMap {
    get {
      if (countryToRegionMap == null) {
        countryToRegionMap = new Map<String, String>();
        for (System_Country_Validation_Record__c country : [
          SELECT Id, Name, Country_Code__c, Region__c
          FROM System_Country_Validation_Record__c
        ]) {
          countryToRegionMap.put(country.Country_Code__c, country.Region__c);
          countryToRegionMap.put(country.Name, country.Region__c);
        }
      }
      return countryToRegionMap;
    }
    set;
  }
}