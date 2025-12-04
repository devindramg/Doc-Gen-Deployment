public with sharing class SignatureRequestController {
    
    /**
* Initiates a signature request for the given Document Lifecycle Configuration.
* Called from LWC as:
*   initiateSignatureRequest({ documentConfigId, signerEmail, documentTitle })
*/
    @AuraEnabled
    public static Id initiateSignatureRequest(String documentConfigId, String signerEmail, String documentTitle) {
        System.debug('SignatureRequestController.initiateSignatureRequest - documentConfigId: ' + documentConfigId);
        System.debug('SignatureRequestController.initiateSignatureRequest - signerEmail: ' + signerEmail);
        System.debug('SignatureRequestController.initiateSignatureRequest - documentTitle: ' + documentTitle);
        
        if (String.isBlank(documentConfigId) || String.isBlank(signerEmail)) {
            throw new AuraHandledException('Document ID and Signer Email are required.');
        }
        
        try {
            Signature_Request__c request = new Signature_Request__c(
                Document_Lifecycle_Configuration__c = documentConfigId,
                SignerEmail__c = signerEmail,
                DocumentTitle__c = documentTitle,
                Status__c = 'Pending',
                RequestDate__c = Datetime.now()
            );
            
            insert request;
            
            createSignatureAudit(request.Id, 'Signature Request Initiated for ' + signerEmail);
            
            return request.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to initiate signature request: ' + e.getMessage());
        }
    }
    
    /**
* Returns basic details for the SignaturePad LWC.
* Called as: getSignatureRequest({ requestId: this.recordId })
*/
    @AuraEnabled(cacheable=true)
    public static SignatureRequestWrapper getSignatureRequest(Id requestId) {
        if (requestId == null) {
            throw new AuraHandledException('Request ID is required.');
        }
        
        Signature_Request__c request = [
            SELECT Id, DocumentTitle__c, SignerEmail__c
            FROM Signature_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];
        
        SignatureRequestWrapper wrapper = new SignatureRequestWrapper();
        wrapper.documentTitle = request.DocumentTitle__c;
        wrapper.signerEmail = request.SignerEmail__c;
        return wrapper;
    }
    
    /**
* Submits a signature (type/draw/upload) for an existing signature request.
* Called from SignaturePad LWC:
*   submitSignature({ requestId, signatureData, signerInfo })
*/
    @AuraEnabled
    public static void submitSignature(Id requestId, String signatureData, String signerInfo) {
        if (requestId == null || String.isBlank(signatureData) || String.isBlank(signerInfo)) {
            throw new AuraHandledException('Request ID, signature data, and signer info are required.');
        }
        
        try {
            Signature_Request__c request = [
                SELECT Id, Status__c
                FROM Signature_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
            system.debug('request:::'+request);
            // Prevent double-signing
            if (request.Status__c == 'Signed') {
                throw new AuraHandledException('This signature request is already signed.');
            }
            system.debug('request111111:::'+request);
            // Parse signer info JSON into strongly-typed wrapper
            SignerInfo info = (SignerInfo) JSON.deserialize(signerInfo, SignerInfo.class);
            
            request.Status__c = 'Signed';
            request.SignedDate__c = Datetime.now();
            request.SignatureData__c = signatureData;
            request.SignerInfoJSON__c = signerInfo;
            request.Signature_Method__c = info.signatureMethod;
            
            update request;
            
            createSignatureAudit(requestId, 'Signature Submitted and Validated by ' + info.signerName);
        } catch (Exception e) {
            throw new AuraHandledException('An error occurred during signature submission: ' + e.getMessage());
        }
    }
    
    /**
* Creates an audit entry for the signature workflow.
*/
    private static void createSignatureAudit(Id recordId, String actionDetail) {
        System.debug('SignatureRequestController.createSignatureAudit - recordId: ' + recordId);
        System.debug('SignatureRequestController.createSignatureAudit - actionDetail: ' + actionDetail);
        
        if (recordId == null || String.isBlank(actionDetail)) {
            return;
        }
        
        try {
            // Only insert if Audit_Trail__c object exists in the org
            if (Schema.getGlobalDescribe().containsKey('Audit_Trail__c')) {
                Audit_Trail__c audit = new Audit_Trail__c(
                    Action__c = 'Signature Workflow',
                    Signature_Request__c = recordId,
                    Details__c = actionDetail,
                    User__c = UserInfo.getUserId()
                );
                insert audit;
            }
        } catch (Exception e) {
            System.debug('Failed to create signature audit trail: ' + e.getMessage());
            // Swallow exception to avoid blocking main flow
        }
    }
    /**
* @description Fetches a list of signature requests for the LWC datatable.
* @return List<Signature_Request__c> A list of signature requests, ordered by most recent.
*/
    @AuraEnabled(cacheable=true)
    public static List<Signature_Request__c> getSignatureRequests() {
        try {
            // Added the 'Name' field to the query
            return [
                SELECT Id,
                Name,
                DocumentTitle__c,
                SignerName__c,
                SignerEmail__c,
                Status__c,
                RequestDate__c,
                OTP_Verification__c
                FROM Signature_Request__c
                ORDER BY RequestDate__c DESC
                LIMIT 200
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Failed to retrieve signature requests: ' + e.getMessage());
        }
    }
    
    
    // ----------------------------------------------------------------------
    // Wrapper Classes
    // ----------------------------------------------------------------------
    public class SignatureRequestWrapper {
        @AuraEnabled public String documentTitle { get; set; }
        @AuraEnabled public String signerEmail { get; set; }
    }
    
    public class SignerInfo {
        @AuraEnabled public String signatureMethod;
        @AuraEnabled public String signerName;
        @AuraEnabled public String signerEmail;
        @AuraEnabled public String timestamp;
    }
}