/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-03-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
// File: force-app/main/default/classes/ApprovalManagerController.cls
public with sharing class ApprovalManagerController {

    @AuraEnabled(cacheable=true)
    public static List<DocumentApproval__c> getPendingApprovals() {
        return [
            SELECT Id, Name, Document__r.Title__c, Status__c, Document__r.CreatedDate
            FROM DocumentApproval__c
            WHERE Approver__c = :UserInfo.getUserId()
            AND Status__c = 'Pending'
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static String submitApproval(Id approvalId, String status, String comments) {
        try {
            DocumentApproval__c approval = [SELECT Id FROM DocumentApproval__c WHERE Id = :approvalId];
            approval.Status__c = status;
            approval.Comments__c = comments;
            update approval;
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error submitting approval: ' + e.getMessage());
        }
    }
}