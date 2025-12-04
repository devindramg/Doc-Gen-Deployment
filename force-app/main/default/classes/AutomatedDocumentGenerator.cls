/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-02-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
// File: force-app/main/default/classes/AutomatedDocumentGenerator.cls
public with sharing class AutomatedDocumentGenerator {

    @InvocableMethod(label='Generate Document from Template' description='Generates a document for a given record using a specified template.')
    public static void generateDocument(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        Request req = requests[0]; // Process one request at a time for simplicity
        
        try {
            // 1. Fetch the template
            DocumentTemplate__c template = [
                SELECT Body__c, Name 
                FROM DocumentTemplate__c 
                WHERE Name = :req.templateName AND IsActive__c = true 
                LIMIT 1
            ];

            // 2. Fetch data from the source record (e.g., Opportunity)
            SObject sourceRecord = Database.query('SELECT Name, Amount, CloseDate FROM ' + req.recordId.getSObjectType().getDescribe().getName() + ' WHERE Id = :req.recordId');
            
            // 3. Assemble the document using your existing engine
            String mergeData = JSON.serialize(sourceRecord.getPopulatedFieldsAsMap());
            String assembledHtml = DocumentAssemblyEngine.assemble(template.Body__c, mergeData, null);

            // 4. Save the assembled document as a file
            ContentVersion cv = new ContentVersion();
            cv.Title = template.Name + ' - ' + sourceRecord.get('Name');
            cv.PathOnClient = cv.Title + '.html';
            cv.VersionData = Blob.valueOf(assembledHtml);
            cv.FirstPublishLocationId = req.recordId; // Link the file to the record
            insert cv;

        } catch (Exception e) {
            // In a real scenario, you would add more robust error handling,
            // like logging to a custom object or sending a notification.
            System.debug('Automated document generation failed: ' + e.getMessage());
        }
    }

    // Inner class to define the inputs for the invocable method
    public class Request {
        @InvocableVariable(required=true label='Source Record ID')
        public Id recordId;

        @InvocableVariable(required=true label='Template Name')
        public String templateName;
    }
}