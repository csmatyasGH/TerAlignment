/***************************************************************************
capture  Apex Errors and chekc of  the originator  batch class has a active
BJM  record with Log Level high  create new  records
***************************************************************************/
trigger BatchApexErrorEvents_Trigger on BatchApexErrorEvent(after insert) {
  
  TriggerX.handleTrigger(batchPlatformEvErrorTriggerXHandler.class);

}