/* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* TableauVizPicklist : Used by Tableau Viz LWC designer panel to select custom metadata definitions
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

global with sharing class TableauVizPicklist extends VisualEditor.DynamicPickList {
    @TestVisible
    private static final String RECORD_PAGE = 'RecordPage';

    private VisualEditor.DynamicPickListRows rows;

    @TestVisible
    public TableauVizPicklist(String pageType, String objectName) {
        this.rows = getDefinitions(pageType, objectName);
    }

    global TableauVizPicklist(VisualEditor.DesignTimePageContext context) {
        this.rows = getDefinitions(context.pageType, context.entityName);
    }

    // Gets filter definitions
    private VisualEditor.DynamicPickListRows getDefinitions(
        String pageType,
        String objectName
    ) {
        VisualEditor.DynamicPickListRows rows = new VisualEditor.DynamicPickListRows();

        if (pageType != RECORD_PAGE) {
            objectName = null;
        }

        // Include null for Current User only based filters
        List<Tableau_Viz_Definition__mdt> vizDefs = [SELECT Id, Label, DeveloperName, Description__c
            FROM Tableau_Viz_Definition__mdt
            WHERE Object_Name__c = :objectName or Object_Name__c = null];

        for (Tableau_Viz_Definition__mdt d : vizDefs) {
            String label = d.Label;
            if (String.isNotEmpty(d.Description__c)) {
                label = label + ' (' + d.Description__c?.abbreviate(45) + ')';
            }
            rows.addRow(
                new VisualEditor.DataRow(
                    label,
                    d.DeveloperName
                )
            );
        }
        return rows;
    }

    global override VisualEditor.DataRow getDefaultValue() {
        return null;
    }

    global override VisualEditor.DynamicPickListRows getValues() {
        return this.rows;
    }
}