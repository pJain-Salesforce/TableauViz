/* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* TableauVizControllerTest : Test Class for TableauVizController, TableauFilterBuilder
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Nathan Shulman  nathan.shulman@bofa.com
* @modifiedBy     Nathan Shulman  nathan.shulman@bofa.com
* @maintainedBy   Nathan Shulman  nathan.shulman@bofa.com
* @version        1.0
* @created        2023-06-14
* @modified       2023-06-20
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @changes
* 2023-06-14   Initial Version
* 2023-06-20   Improved Assertions
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
@isTest
public with sharing class TableauVizControllerTest {
    @TestSetup
    static void createData(){
        Id accRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business').getRecordTypeId();
        Account pEntity = new Account(Name = 'testEntity');//Business
        pEntity.FinServ__InvestmentObjectives__c = 'Growth;Income';
        pEntity.RecordTypeId = accRecTypeId;
        insert pEntity;
        TableauVizControllerTest.insertContact(pEntity.Id,'1');
    }

    // Create a test contact and append with num string
    static void insertContact(Id accId, String num) {
        Contact con = new Contact();
        Id conRecTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('EntityContact').getRecordTypeId();
        con.LastName = 'testContact' + num;
        con.AccountId = accId;
        con.Email =  'test' + num + '@test.com';
        con.Phone  = '9999999999';
        con.RecordTypeId = conRecTypeId;
        insert con;
    }

    @isTest
    static void getFilters() {
        List<Account> lstAccount = new  List <Account>([Select Id, Name from Account where Name ='testEntity' limit 1]);
        Account acc = lstAccount[0];
        // Must have valid definition
        List<Tableau_Viz_Definition__mdt> defs = [Select Id, DeveloperName from Tableau_Viz_Definition__mdt limit 1];
        Tableau_Viz_Definition__mdt def = defs[0];
        Map<String, Object> results = TableauVizController.getFiltersByRecordId(def.DeveloperName, acc.Id);
        System.assertNotEquals(null,results.get('filters'),'Filter property should be set on the results.');
    }

    @isTest
    static void testFail() {
        // Must have valid def
        List<Tableau_Viz_Definition__mdt> defs = [Select Id, DeveloperName from Tableau_Viz_Definition__mdt limit 1];
        Tableau_Viz_Definition__mdt def = defs[0];
        Map<String, Object> results = null;
        try {
            results = TableauVizController.getFiltersByRecordId(def.DeveloperName, '0');
        } catch (Exception e) {
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Invalid ID should throw error');
        }
    }

    // Test Multiselect and Child Query builder method
    @isTest
    static void testMultiSelect() {
        // Must have valid def and setting
        List<Tableau_Viz_Definition__mdt> defs = [Select Id, DeveloperName FROM Tableau_Viz_Definition__mdt LIMIT 1];
        Tableau_Viz_Definition__mdt def = defs[0];
        List<Tableau_Viz_Setting__mdt> vsets = [Select Id, Field_Name__c, Relationship_Name__c FROM Tableau_Viz_Setting__mdt LIMIT 1];
        Tableau_Viz_Setting__mdt vset = vsets[0];
        List<Account> lstAccount = new  List <Account>([Select Id, FinServ__InvestmentObjectives__c from Account where Name ='testEntity' limit 1]);
        Account acc = lstAccount[0];
        TableauFilterBuilder tfb = new TableauFilterBuilder(def.DeveloperName,acc.Id);
        List<String> multi = tfb.getMultiPickVals(acc, 'FinServ__InvestmentObjectives__c', acc.FinServ__InvestmentObjectives__c);
        Map<String,Object> filters = tfb.getFilters();
        System.assertEquals(2, multi.size(), 'Multi select with 2 values should create a list with 2 elements');

        String cq = tfb.getChildQuery(vset);
        System.assertNotEquals(cq, null);
    }

    @isTest
    static void testNoFilters() {
        List<Account> lstAccount = new  List <Account>([Select Id, FinServ__InvestmentObjectives__c from Account where Name ='testEntity' limit 1]);
        Account acc = lstAccount[0];
        TableauFilterBuilder tbf = new TableauFilterBuilder('test', acc.Id);
        System.assertEquals(null, tbf.filters, 'Filter Builder should have null filter value when no values exist on the field');
        Map<String,Object> result = tbf.getFilters();
        System.assertEquals(null, result, 'Filter Builder getFilters method should not return filters when no values exist on the field');
    }

    // Test retrieving related child record fields and other types
    @isTest
    static void testChildQuery() {
        List<Tableau_Viz_Definition__mdt> defs = [Select Id, DeveloperName FROM Tableau_Viz_Definition__mdt LIMIT 1];
        Tableau_Viz_Definition__mdt def = defs[0];
        List<Tableau_Viz_Setting__mdt> vsets = [Select Id, Field_Name__c, Relationship_Name__c FROM Tableau_Viz_Setting__mdt LIMIT 1];
        Tableau_Viz_Setting__mdt vset = vsets[0];
        List<Account> lstAccount = new  List <Account>([Select Id, FinServ__InvestmentObjectives__c,
            (SELECT FirstName, Title, Account.Name,
                Account.FinServ__InvestmentObjectives__c FROM Contacts)
            FROM Account where Name ='testEntity' limit 1]);
        Account acc = lstAccount[0];
        TableauFilterBuilder tbf = new TableauFilterBuilder(def.developerName, acc.Id);

        Tableau_Viz_Setting__mdt vs = tbf.vizSettings[0];
        // modify the setting to support Record vs user
        vs.Type__c = 'USERFIELD';
        tbf.buildFieldLists();
        System.assertNotEquals(null, tbf.filters, 'Filters should not be returned for no values on user');

        // modify the setting to support Record vs user
        vs.Type__c = 'RECORDFIELD';
        tbf.buildFieldLists();
        System.assertNotEquals(null, tbf.filters, 'Filters should not be returned when record field has no values');

        // modify the setting to support Child Records
        vs.Type__c = 'USERCHILDREC';
        vs.Selection__c = true;
        tbf.buildFieldLists();
        System.assertNotEquals(null, tbf.filters, 'Filters should not be returned when there are no related child records');

        // modify the setting to support User Child Records
        vs.Type__c = 'CHILDREC';
        vs.Relationship_Name__c = 'Contacts';
        tbf.buildFieldLists();
        tbf.addFilter(vs);

        //first test: null rec
        List<String> children = tbf.getChildValues(vs, null);
        System.assertEquals(null, children, 'No child records should be returned when record is null');

        //second test: record with subquery results
        //And traversing fields
        vs.Field_Name__c = 'Account.Name';
        children = tbf.getChildValues(vs, acc);
        System.assertNotEquals(null, children, 'With related child values, children should not be null');

        vs.Field_Name__c = 'Account.Gotcha__c';
        children = tbf.getFieldValues(vs, acc);
        System.assertEquals(null, children, 'Children should be null when Traversing to an invalid field');

        //test combo subquery, traversal and multiselect
        vs.Field_Name__c = 'Account.FinServ__InvestmentObjectives__c';
        children = tbf.getChildValues(vs, acc);
        System.assertNotEquals(null, children, 'Children should be set when field is valid and has values');

         // Test filter on multi-select, which should have 2 results
        vs.Type__c = 'RECORDFIELD';
        vs.Field_Name__c = 'FinServ__InvestmentObjectives__c';
        tbf.contextRec = acc;
        tbf.addFilter(vs);
        System.assertEquals(1, tbf.filters.size(), 'One filter value should be returned from Investment Objectives record field');

        // Test filter wrapper object
        TableauFilterBuilder.filterWrapper fw = new TableauFilterBuilder.filterWrapper();
        fw.Name = 'test';
        fw.Values = new List<String>{'test'};
        fw.SelectionOnly = false;
        tbf.filterList = new List<TableauFilterBuilder.filterWrapper>{fw};
        System.assertEquals(1, fw.Values.size(), 'Filters should have one string value');
        System.assertEquals(1, tbf.filterList.size(), 'One filter should be stored in the filter list');

        List<String> result = tbf.getFieldValues(vs, null);
        System.assertEquals(null, result, 'Null record should have null result for getFieldValues');
    }
}