/* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* TableauVizPicklistTest : Test classes for TableauVizPicklist
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

@IsTest(IsParallel=true)
public with sharing class TableauVizPicklistTest {
    @isTest
    static void getCustomMetadataValues() {
        TableauVizPicklist pickList = new TableauVizPicklist(
            TableauVizPicklist.RECORD_PAGE,
            'Account'
        );
        VisualEditor.DynamicPickListRows rows = pickList.getValues();
        System.assert(rows.size() > 0, 'Fields not found');
    }

    @isTest
    static void getDefaultCustomMetadataValue() {
        TableauVizPicklist pickList = new TableauVizPicklist(
            TableauVizPicklist.RECORD_PAGE,
            'Account'
        );
        System.assertEquals(pickList.getDefaultValue(), null, 'Default should be null for Account record');

        // non record page
        TableauVizPicklist pickListNonRecord = new TableauVizPicklist(
            'Something Else',
            'Account'
        );
        System.assertEquals(pickList.getDefaultValue(), null, 'Default value should be null for invalid type');
    }

    @isTest
    static void getDefaultCustomMetadataValueContext() {
        VisualEditor.DesignTimePageContext context = new VisualEditor.DesignTimePageContext();
        context.pageType = TableauVizPicklist.RECORD_PAGE;
        context.entityName = 'Account';
        TableauVizPicklist pickList = new TableauVizPicklist(context);
        System.assertEquals(pickList.getDefaultValue(), null, 'Default value should be null for Account picklist');
    }
}