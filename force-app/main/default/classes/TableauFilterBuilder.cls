/* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* TableauFilterBuilder : Class to generate LWC Viz filters from custom metadata
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
* Additional Info:
*
* This is used to build the filters used by the TableauViz LWC
* It's much easier and cleaner to break the logic into multiple methods and
* class properties instead of static methods and passing multiple params.
* The static method using this class (required by LWC) is in TableauVizController.cls
*/

public with sharing class TableauFilterBuilder {
    private Id recId {get; set;}
    @TestVisible
    private Map<String, Object> filters {get; set;}
    private Set<String> selections {get; set;}
    @TestVisible
    private List<FilterWrapper> filterList {get; set;}

    // Unique viz settings from Custom metadata
    @TestVisible
    private List<Tableau_Viz_Setting__mdt> vizSettings {get; set;}
    private Tableau_Viz_Definition__mdt vizDefinition {get; set;}
    private String objectName {get; set;}
    private List<String> objectFieldNames;
    private List<String> userFieldNames;
    @TestVisible
    sObject contextRec {get; set;}
    User userRec {get; set;}

    // API Names of different setting types: Field Value on the record, Field value array from child records,
    // Field Value on user, or Array of Field Values on User Related child records
    @TestVisible
    private Enum SettingType {RECORDFIELD, CHILDREC, USERFIELD, USERCHILDREC}

    // Constructor - metadata name and record Id are required
    public TableauFilterBuilder(String vizDeveloperName, Id recordId) {
        // Get the unique viz settings from Custom Metadata based on the parent definition name
        vizSettings = [SELECT Id, Label, Field_Name__c, Filter_Name__c,
            Type__c, Relationship_Name__c, Selection__c
            FROM Tableau_Viz_Setting__mdt
            WHERE Tableau_Viz_Definition__r.DeveloperName = :vizDeveloperName];

        // Set null filter if no settings
        if (vizSettings.Size() == 0) {
            filters = null;
        } else {
            this.recId = recordId;
            loadDefinition(vizDeveloperName);
            init();
        }
    }

    // Get information about the definition
    private void loadDefinition(String vizDeveloperName) {
        vizDefinition = [SELECT Id, MasterLabel, Default_Worksheet__c, Description__c, Object_Name__c
            FROM Tableau_Viz_Definition__mdt
            WHERE DeveloperName = :vizDeveloperName];

    }

    // Set initial prop values
    private void init() {
        this.filters = new Map<String,Object>();
        this.selections = new Set<String>();
        // Get the object name from the first setting record (they're all the same)
        if (vizSettings?.Size() > 0 && vizDefinition != null) {
            this.objectName = vizDefinition.Object_Name__c;
        }
        objectFieldNames = new List<String>();
        userFieldNames = new List<String>();
    }

    // Walk through settings and build the filters object
    public Map<String,Object> getFilters() {
        // If not settings, skip all the steps
        if (vizSettings == null || vizSettings.Size() == 0) {
            return null;
        }
        buildFieldLists();
        loadRecords();
        addFilters();

        // Create a wrapper around filters with additional info
        Map<String, Object> result = new Map<String,Object>();
        // Pivot the filters into a list of objects
        List<Map<String, Object>> filterList = new List<Map<String, Object>>();
        for (String filterName : this.filters.keySet()) {
            Map<String, Object> filter = new Map<String, Object>();
            filter.put('name', filterName);
            filter.put('values', this.filters.get(filterName));
            filter.put('selectionOnly', this.selections.contains(filterName));
            filterList.add(filter);
        }
        result.put('filters', filterList);
        result.put('worksheet', this.vizDefinition?.Default_Worksheet__c);
        return result;
    }

    // Create lists of fields for record object, user object, and child record subqueries
    @TestVisible
    private void buildFieldLists() {
        objectFieldNames.add('Id');
        userFieldNames.add('Id');

        // build field and subquery list for either the related record or the current user
        for (Tableau_Viz_Setting__mdt vs : vizSettings) {
            SettingType st = SettingType.valueOf(vs.Type__c);
            switch on st {
                when RECORDFIELD {
                    objectFieldNames.add(vs.Field_Name__c);
                }
                when USERFIELD {
                    userFieldNames.add(vs.Field_Name__c);
                }
                when CHILDREC {
                    // Build subquery for child relationship objects
                    String subquery = getChildQuery(vs);
                    objectFieldNames.add(subquery);
                }
                when USERCHILDREC {
                    // Build subquery for child relationship objects
                    String subquery = getChildQuery(vs);
                    userFieldNames.add(subquery);
                }
            }
            if (vs.Selection__c) {
                selections.add(vs.Filter_Name__c);
            }
        }
    }

    // Common child record subquery builder
    @TestVisible
    private String getChildQuery(Tableau_Viz_Setting__mdt vs) {
        return '(SELECT Id, '
                    + vs.Field_Name__c + ' FROM '
                    + vs.Relationship_Name__c + ')';
    }

    // Load the two records we will need to build the filters
    private void loadRecords() {
        // Load the related record where the dashboard is hosted
        this.contextRec = loadRecord(objectName, objectFieldNames, this.recId);
        // Current user record
        this.userRec = (User)loadRecord('User', userFieldNames, UserInfo.getUserId());
    }

    // Adding the actual filter values happens in the second pass
    // Records have already been loaded, so use the record data and settings to build the values
    // build filters from results
    private void addFilters() {
        for (Tableau_Viz_Setting__mdt vs : vizSettings) {
            addFilter(vs);
        }
    }

    // Logic for determining type of field and adding correctly to the filter object
    @TestVisible
    private void addFilter(Tableau_Viz_Setting__mdt vs) {
        // Get the setting type as Enum
        SettingType st = SettingType.valueOf(vs.Type__c);
        // Store which record we'll use for this filter, user or related record
        sObject targetRec = (st == SettingType.USERFIELD || st == SettingType.USERCHILDREC)
            ? this.userRec : this.contextRec;
        List<String> values = null;
        switch on st {
            when RECORDFIELD, USERFIELD {
                values = getFieldValues(vs, targetRec);
            }
            when CHILDREC, USERCHILDREC {
                values = getChildValues(vs, targetRec);
            }
        }
        if (values?.size() == 1) {
            // Single value doesn't need to be passed in an array
            filters.put(vs.Filter_Name__c, values[0]);
        } else if (values?.size() > 1) {
            // Multiple values need to be passed in an array
            filters.put(vs.Filter_Name__c, values);
        }
    }

    // Helper to load record dynamically by sObject type
    private sObject loadRecord(String objectName, List<String> fields, Id objectId) {
        // No need to run the query if we have no fields or Id
        if (fields == null || fields.size() == 1 || objectId == null) {
            return null;
        }
        String query = 'SELECT ' + String.join(fields, ',') + ' FROM ' + objectName + ' WHERE Id = :objectId';
        return Database.query(query);
    }

    // Helper to return field types for a given object
    private Map<String, Schema.SObjectField> getObjectFields(String objectTypeName) {
        String[] objectNames = new List<String>{ objectTypeName };
        Schema.DescribeSobjectResult[] objects = Schema.describeSObjects(
            objectNames
        );
        Schema.DescribeSobjectResult objectInfo = objects[0];
        // Get results for this object
        return objectInfo.fields.getMap();
    }

    // If the field is a multi-select picklist, return the values as a list
    // otherwise, return null
    @TestVisible
    private List<String> getMultiPickVals(sObject rec, String fieldName, String fieldValue) {
        Map<String, Schema.SObjectField> fields = getObjectFields(rec.getSObjectType().getDescribe().getName());
        Schema.SObjectField field = fields.get(fieldName);
        Schema.DisplayType fieldType = field.getDescribe().getType();
        if (fieldType == Schema.DisplayType.MULTIPICKLIST) {
            return fieldValue?.split(';');
        }
        return null;
    }

    // Helper to create an array of values from a child relationship
    @TestVisible
    private List<String> getChildValues(Tableau_Viz_Setting__mdt vs, sObject rec) {
        // Without a record or child relationship, this is invalid
        String relName = vs.Relationship_Name__c;
        if (rec == null || relName == null) {
            return null;
        }
        // Track only unique, non empty values
        Set<String> valueSet = new Set<String>();
        //Grab values from child record list given the field name
        List<sObject> childRecords = (List<sObject>)rec.getSObjects(vs.Relationship_Name__c);
        for (sObject childRecord : childRecords) {
            List<String> values = getFieldValues(vs, childRecord);
            // Only add non empty/null/whitespace/blank
            if (values?.size() > 0) {
                valueSet.addAll(values);
            }
        }
        return new List<String>(valueSet);
    }

    // Helper to load record fields with dot notation support if needed
    @TestVisible
    private List<String> getFieldValues(Tableau_Viz_Setting__mdt vs, sObject rec) {
        // Without a record, this is invalid
        if (rec == null) {
            return null;
        }
        String fieldPath = vs.Field_Name__c;
        String fieldName = null;
        List<String> values = new List<String>();
        if (fieldPath.contains('.')) {
            // Traverse related records, but stop 1 prior to last element (that's our field)
            List<String> parts = fieldPath.split('\\.');
            for (Integer i=0; i<parts.size()-1; i++) {
                Map<String, Object> recMap = rec.getPopulatedFieldsAsMap();
                if (recMap.containsKey(parts[i])) {
                    rec = (sObject)recMap.get(parts[i]);
                } else {
                    // If we can't find the field, we can't traverse it
                    return null;
                }
            }
            // Get name of this field on the last related record we've traversed
            fieldName = parts[parts.size()-1];
        } else {
            fieldName = fieldPath;
        }
        String fieldVal = String.valueOf(rec.get(fieldName));
        
        // If this is a multiselect picklist, it will be a list of values
        List<String> pickvals = getMultiPickVals(rec, fieldName, fieldVal);
        if (pickvals != null) {
            values.addAll(pickvals);
        } else {
            values.add(fieldVal);
        }
        return values;
    }

    public class FilterWrapper {
        // Name of filter
        @AuraEnabled
        public String name {get; set;}
        // Value or array of values for filter
        @AuraEnabled
        public List<String> values {get; set;}
        // If true, use selection rather than filter
        @AuraEnabled
        public Boolean selectionOnly {get; set;}
    }
}