/* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* TableauVizController : Static call for LWC to build filters based on definition name
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Nathan Shulman  nathan.shulman@bofa.com
* @modifiedBy     Nathan Shulman  nathan.shulman@bofa.com
* @maintainedBy   Nathan Shulman  nathan.shulman@bofa.com
* @version        1.0
* @created        2023-06-14
* @modified       2023-06-14
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @changes
* 2023-06-14   Initial Version
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

public with sharing class TableauVizController {
    // Given a Custom Metadata DeveloperName, pull filters with field values for a given record
    @AuraEnabled
    public static Map<String,Object> getFiltersByRecordId(String vizDeveloperName, String recordId){
        try {
            TableauFilterBuilder fb = new TableauFilterBuilder(vizDeveloperName, recordId);
            return fb.getFilters();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}