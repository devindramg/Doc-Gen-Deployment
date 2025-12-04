/**
 * @description Service for executing compliance rules stored in Custom Metadata.
 */
public with sharing class ValidationService {

    /**
     * @description Retrieves all active compliance rules.
     * @param templateId The context template ID (currently unused, for future expansion).
     * @return List<ComplianceRule__mdt> A list of active rules.
     */
    public static List<ComplianceRule__mdt> getRulesForTemplate(String templateId) {
        // For now, we get all active rules. This can be enhanced to filter by template.
        return [
            SELECT MasterLabel, RuleLogic__c, ErrorMessage__c
            FROM ComplianceRule__mdt
            WHERE IsActive__c = true
        ];
    }

    /**
     * @description Executes a list of rules against a set of JSON data.
     * @param rules The list of rules to execute.
     * @param jsonData The data to validate.
     * @return DocumentGenerationController.ComplianceResult The outcome of the validation.
     */
    public static DocumentGenerationController.ComplianceResult execute(List<ComplianceRule__mdt> rules, String jsonData) {
        List<String> errorMessages = new List<String>();
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(jsonData);

        for (ComplianceRule__mdt rule : rules) {
            // NOTE: This is a simplified rule evaluator for demonstration.
            // Example RuleLogic__c: "opportunity.Amount!= null"
            String fieldPath = rule.RuleLogic__c.split(' ')[0]; // e.g., "opportunity.Amount"
            Object value = getValueFromPath(data, fieldPath);

            if (value == null || (value instanceof String && String.isBlank((String)value))) {
                errorMessages.add(rule.ErrorMessage__c);
            }
        }
        
        Boolean isCompliant = errorMessages.isEmpty();
        return new DocumentGenerationController.ComplianceResult(isCompliant, errorMessages);
    }

    /**
     * @description Helper to navigate a JSON map using a dot-notation path.
     */
    private static Object getValueFromPath(Map<String, Object> data, String path) {
        List<String> keys = path.split('\\.');
        Object currentObject = data;

        for (String key : keys) {
            if (currentObject instanceof Map<String, Object>) {
                currentObject = ((Map<String, Object>)currentObject).get(key);
            } else {
                return null; // Path is invalid
            }
        }
        return currentObject;
    }
}