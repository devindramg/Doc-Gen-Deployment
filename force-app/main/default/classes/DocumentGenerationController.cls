/**
* @description Central controller for Document Generation.
* Handles template management, document assembly,
* and final generation with AI model integration.
* @author Anara AI (Updated & Merged)
* @version 2.7
* @last modified on: 11-26-2025
*/
public with sharing class DocumentGenerationController {
    
    //====================================================
    // METHODS FOR: templateManager & templateEditor LWC
    //====================================================
    
    @AuraEnabled(cacheable=true)
    public static List<DocumentTemplate__c> getDocumentTemplates() {
        return [
            SELECT 
            Id, 
            Name, 
            Body__c, 
            Version__c, 
            IsActive__c,
            // --- ADD THESE THREE FIELDS ---
            Region1__c, 
            Role__c, 
            Contract_Type__c 
            FROM DocumentTemplate__c 
            ORDER BY CreatedDate DESC
        ];
    }
    
    
    @AuraEnabled
    public static Id saveTemplate(DocumentTemplate__c templateRecord) {
        if (!Schema.sObjectType.DocumentTemplate__c.isCreateable() ||
            !Schema.sObjectType.DocumentTemplate__c.isUpdateable()) {
                throw new AuraHandledException(
                    'You do not have permission to create or update Document Templates.'
                );
            }
        System.debug('templateRecord::::::'+templateRecord);
        upsert templateRecord;
        return templateRecord.Id;
    }
    
    //====================================================
    // METHODS FOR: documentGenerator LWC - UPDATED WITH AI MODEL
    //====================================================
    
    // No changes to this method
    @AuraEnabled(cacheable=true)
    public static List<DocumentTemplate__c> getActiveTemplatesForSelection() {
        return [
            SELECT Id, Name,Region1__c
            FROM DocumentTemplate__c
            WHERE IsActive__c = true
            ORDER BY CreatedDate DESC
        ];
    }
    
    
    // Fetch available AI models
    @AuraEnabled(cacheable=true)
    public static List<AIModelManager.AIModelConfig> getAvailableAIModels() {
        return AIModelManager.getAvailableAIModels();
    }
    
    // Generates a clause suggestion using the specified AI model
    @AuraEnabled
    public static String generateClauseWithAI(
        String modelId,
        String prompt,
        String jsonContext
    ) {
        try {
            String response = AIModelManager.processWithEinstein(
                modelId,
                prompt,
                jsonContext
            );
            
            ClauseGenerator.logAIGeneration(
                modelId,
                prompt,
                response,
                'Success',
                null
            );
            
            return response;
            
        } catch (Exception e) {
            ClauseGenerator.logAIGeneration(
                modelId,
                prompt,
                null,
                'Error',
                e.getMessage()
            );
            throw new AuraHandledException(
                'AI Clause Generation Failed: ' + e.getMessage()
            );
        }
    }
    
    //====================================================
    // PREVIEW DOCUMENT
    //====================================================
    
    // --- MODIFIED METHOD: PREVIEWDOCUMENT ---
    /**
* @description Generates a real-time preview by merging a template with multiple data sources.
* @param templateId The ID of the DocumentTemplate__c record.
* @param jsonData A JSON string of primary data (e.g., contact details).
* @param aiClauseText Optional AI-generated text to be merged.
* @return A PreviewResult wrapper with the rendered HTML or errors.
*/
    @AuraEnabled
    public static PreviewResult previewDocument(Id templateId, String jsonData, String aiClauseText) {

        System.debug('templateId::::'+templateId);
        System.debug('jsonData::::'+jsonData);
        System.debug('aiClauseText:::::'+aiClauseText);
        PreviewResult result = new PreviewResult();
        
        // --- Input Validation ---
        if (templateId == null) {
            result.success = false;
            result.validationErrors.add('Validation Error: Template ID is required.');
            return result;
        }
        
        try {
            // --- Step 1: Securely Query the Template Record ---
            List<DocumentTemplate__c> templates = [
                SELECT Name, Body__c, Version__c, Region1__c, Role__c, Contract_Type__c
                FROM DocumentTemplate__c
                WHERE Id = :templateId
                LIMIT 1
            ];
            
            if (templates.isEmpty()) {
                result.success = false;
                result.validationErrors.add('Preview Error: No Document Template found with ID: ' + templateId);
                return result;
            }
            
            DocumentTemplate__c template = templates[0];
            
            // Assign template name to response
            result.templateName = template.Name;
            
            // --- Step 2: Create a Master Data Map for All Merge Sources ---
            Map<String, Object> masterMergeData = new Map<String, Object>();
            
            // Add user-provided JSON data
            if (String.isNotBlank(jsonData)) {
                Map<String, Object> jsonDataMap = 
                    (Map<String, Object>) JSON.deserializeUntyped(jsonData);
                masterMergeData.putAll(jsonDataMap);
            }
            
            // Add template metadata under 'template'
            Map<String, Object> templateData = new Map<String, Object>{
                'Name'            => template.Name,
                    'Version__c'      => template.Version__c,
                    'Region1__c'       => template.Region1__c,
                    'Role__c'         => template.Role__c,
                    'Contract_Type__c'=> template.Contract_Type__c
                    };
                        masterMergeData.put('template', templateData);
            
            // Add AI clause text if provided
            if (String.isNotBlank(aiClauseText)) {
                masterMergeData.put('aiClause', aiClauseText);
            }
            
            // --- Step 3: Merge Everything into the Template Body ---
            result.renderedContent = DocumentAssemblyEngine.merge1(template.Body__c, masterMergeData);
            
            result.success = true;
            
        } catch (JSONException e) {
            result.success = false;
            result.validationErrors.add(
                'JSON Parsing Error: The provided data is not valid. Details: ' + e.getMessage()
            );
            
        } catch (Exception e) {
            result.success = false;
            result.validationErrors.add('Preview Error: ' + e.getMessage());
        }
        system.debug('result:::::'+result);
        return result;
    }
    

    //====================================================
    // FINAL DOCUMENT GENERATION
    //====================================================
    
    @AuraEnabled
    public static FinalGenerationResult generateFinalDocument(
        String templateId,
        String jsonData,
        String aiClauseText,
        String selectedAIModel
    ) {
        FinalGenerationResult result = new FinalGenerationResult();
        
        if (!Schema.sObjectType.DocumentLifecycleConfiguration__c.isCreateable() ||
            !Schema.sObjectType.ContentVersion.isCreateable()) {
                result.success = false;
                result.errorMessage =
                    'You do not have permission to create document records or files.';
                return result;
            }
        
        try {
            String decodedJsonData = jsonData.unescapeHtml4();
            
            PreviewResult preview =
                previewDocument(templateId, decodedJsonData, aiClauseText);
            
            if (!preview.success) {
                result.errorMessage =
                    String.join(preview.validationErrors, '; ');
                return result;
            }
            
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Generated Document - ' + System.now().format();
            cv.PathOnClient = cv.Title + '.html';
            cv.VersionData = Blob.valueOf(preview.renderedContent);
            cv.IsMajorVersion = true;
            
            insert cv;
            
            ContentVersion savedCv = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];
            
            if (savedCv != null) {
                DocumentLifecycleConfiguration__c docConfig =
                    new DocumentLifecycleConfiguration__c(
                        Name__c = cv.Title,
                        ContentDocumentString__c = savedCv.ContentDocumentId,
                        AI_Model_Used__c = selectedAIModel
                    );
                
                insert docConfig;
                
                result.success = true;
                result.recordId = docConfig.Id;
                result.contentDocumentId = savedCv.ContentDocumentId;
                result.aiModelUsed = selectedAIModel;
            }
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage =
                'Failed to create the document file: ' + e.getMessage();
        }
        
        return result;
    }
    
    //====================================================
    // CREATE DOCUMENT REQUEST WITH AI
    //====================================================
    
    @AuraEnabled
    public static String createDocumentRequest(
        String contractType,
        String region,
        String role,
        String additionalRequirements,
        String selectedAIModel
    ) {
        try {
            if (String.isBlank(contractType) ||
                String.isBlank(region) ||
                String.isBlank(role)) {
                    throw new AuraHandledException(
                        'Contract type, region, and role are required'
                    );
                }
            
            String generatedClause =
                ClauseGenerator.generateClause(
                    region,
                    role,
                    contractType,
                    selectedAIModel
                );
            
            if (String.isBlank(generatedClause)) {
                throw new AuraHandledException(
                    'Failed to generate document clause'
                );
            }
            
            Boolean isCompliant =
                ComplianceChecker.validateClause(
                    generatedClause,
                    region,
                    contractType
                );
            
            String complianceStatus =
                isCompliant ? 'COMPLIANT' : 'REQUIRES_REVIEW';
            
            DocumentLifecycleConfiguration__c docConfig =
                new DocumentLifecycleConfiguration__c(
                    Region__c = region,
                    Role__c = role,
                    ContractType__c = contractType,
                    GeneratedClause__c = generatedClause,
                    ComplianceStatus__c = complianceStatus,
                    ProcessingStatus__c = 'GENERATED',
                    AIProcessingEnabled__c = true,
                    AI_Model_Used__c = selectedAIModel
                );
            
            if (String.isNotBlank(additionalRequirements)) {
                docConfig.GeneratedClause__c +=
                    '\n\nAdditional Requirements:\n' +
                    additionalRequirements;
            }
            
            insert docConfig;
            return docConfig.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException(
                'Document generation failed: ' + e.getMessage()
            );
        }
    }
    
    //====================================================
    // METHODS FOR: documentViewer LWC
    //====================================================
    
    @AuraEnabled(cacheable=true)
    public static DocumentViewerWrapper getDocumentDetailsForViewer(
        Id recordId
    ) {
        DocumentViewerWrapper result = new DocumentViewerWrapper();
        
        result.document = [
            SELECT Id, Name, CreatedDate, ContentDocumentString__c,
            AI_Model_Used__c,
            (SELECT Id, Status__c, SignedDate__c,
             Signature_Method__c, SignerEmail__c
             FROM Signature_Requests__r
             ORDER BY CreatedDate DESC
             LIMIT 1)
            FROM DocumentLifecycleConfiguration__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        
        if (!result.document.Signature_Requests__r.isEmpty()) {
            result.signatureRequest =
                result.document.Signature_Requests__r[0];
        }
        
        result.auditTrails = [
            SELECT Id, Action__c, Details__c,
            CreatedDate, User__r.Name
            FROM Audit_Trail__c
            WHERE Record_Id__c = :recordId
            ORDER BY CreatedDate DESC
        ];
        
        if (String.isNotBlank(
            result.document.ContentDocumentString__c)) {
                
                List<ContentVersion> versions = [
                    SELECT VersionData
                    FROM ContentVersion
                    WHERE ContentDocumentId =
                    :result.document.ContentDocumentString__c
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                
                if (!versions.isEmpty()) {
                    result.renderedContent =
                        versions[0].VersionData.toString();
                } else {
                    result.renderedContent =
                        'Error: Document file not found for the linked ID.';
                }
            } else {
                result.renderedContent =
                    'Error: No document has been linked to this record.';
            }
        
        return result;
    }
    @AuraEnabled
    public static Id createApprovalRequest(Id contentVersionId, Id approverId) {
        // Validate inputs to prevent errors
        if (contentVersionId == null || approverId == null) {
            throw new AuraHandledException('Content Version ID and Approver ID are required.');
        }
        
        try {
            // Create the new Document Approval record
            DocumentApproval__c newApproval = new DocumentApproval__c();
            newApproval.Document__c = contentVersionId; // Link to the document
            newApproval.Approver__c = approverId;       // Assign to the selected user
            newApproval.Status__c = 'Pending';          // Set the initial status
            
            insert newApproval;
            
            // Return the ID of the newly created approval record
            return newApproval.Id;
            
        } catch (Exception e) {
            // If something goes wrong, pass a clear error message back to the LWC
            throw new AuraHandledException('Failed to create approval request: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<DocumentLifecycleConfiguration__c>
        getDocumentsForViewer() {
            
            return [
                SELECT Id, Name, Status__c,
                CreatedDate, AI_Model_Used__c
                FROM DocumentLifecycleConfiguration__c
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        }
    
    //====================================================
    // WRAPPER CLASSES
    //====================================================
    
    public class PreviewResult {
        @AuraEnabled public String aiModelUsed;
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String templateName { get; set; }     // Added property
        @AuraEnabled public String renderedContent { get; set; }
        @AuraEnabled public List<String> validationErrors { get; set; }
        
        public PreviewResult() {
            this.success = false;
            this.validationErrors = new List<String>();
        }
        
        
    }
    
    public class FinalGenerationResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String aiModelUsed;
        
        public FinalGenerationResult() {
            this.success = false;
        }
    }
    
    public class DocumentViewerWrapper {
        @AuraEnabled public DocumentLifecycleConfiguration__c document;
        @AuraEnabled public Signature_Request__c signatureRequest;
        @AuraEnabled public List<Audit_Trail__c> auditTrails;
        @AuraEnabled public String renderedContent;
        @AuraEnabled public String aiModelInfo;
    }
}