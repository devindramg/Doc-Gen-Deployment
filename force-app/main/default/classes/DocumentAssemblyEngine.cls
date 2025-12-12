/**
* @description Document Assembly Engine with AI-powered clause generation and template merging.
*              Handles standard merge field substitution and optional AI-enhanced content generation.
* @author      Anara AI (Updated)
* @version     2.5
* @last modified 11-25-2025
*/
public with sharing class DocumentAssemblyEngine {
    
    //======================================================
    // MAIN ASSEMBLY METHOD – WITH AI MODEL INTEGRATION
    //======================================================
    @AuraEnabled
    public static String assemble(String templateContent, String mergeData, String aiModel) {
        try {
            // Parse merge data
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(mergeData);
            
            // Standard merge field substitution
            String assembledContent = performStandardSubstitution(templateContent, dataMap);
            
            // Apply optional AI enhancement
            if (String.isNotBlank(aiModel)) {
                assembledContent = enhanceWithAI(assembledContent, dataMap, aiModel);
            }
            
            return assembledContent;
            
        } catch (Exception e) {
            throw new AuraHandledException('Document assembly failed: ' + e.getMessage());
        }
    }
    
    
    //======================================================
    // STANDARD MERGE FIELD SUBSTITUTION
    //======================================================
    private static String performStandardSubstitution(String template, Map<String, Object> dataMap) {
        String result = template;
        
        for (String key : dataMap.keySet()) {
            Object value = dataMap.get(key);
            
            // Nested object (e.g., contact.Name)
            if (value instanceof Map<String, Object>) {
                Map<String, Object> nestedMap = (Map<String, Object>) value;
                
                for (String nestedKey : nestedMap.keySet()) {
                    String mergeField = '{{' + key + '.' + nestedKey + '}}';
                    String altField = '{' + key + '.' + nestedKey + '}';
                    String replacement = String.valueOf(nestedMap.get(nestedKey));
                    
                    result = result.replace(mergeField, replacement);
                    result = result.replace(altField, replacement);
                }
            }
            
            // Simple field (e.g., {{documentType}})
            else {
                String mergeField = '{{' + key + '}}';
                String altField = '{' + key + '}';
                String replacement = String.valueOf(value);
                
                result = result.replace(mergeField, replacement);
                result = result.replace(altField, replacement);
            }
        }
        
        return result;
    }
    
    
    //======================================================
    // AI-ENHANCED CONTENT GENERATION
    //======================================================
    private static String enhanceWithAI(String baseContent, Map<String, Object> contextData, String aiModel) {
        try {
            
            // Extract context
            String documentType = (String) contextData.get('documentType');
            String region = (String) contextData.get('region');
            String role = (String) contextData.get('role');
            
            String enhancedContent = baseContent;
            
            // Identify where AI clauses need to be inserted
            List<String> aiSections = identifyAISections(baseContent);
            
            for (String section : aiSections) {
                String aiClause = ClauseGenerator.generateClause(region, role, documentType, aiModel);
                
                if (String.isNotBlank(aiClause)) {
                    enhancedContent += '\n\n\n' + aiClause;
                }
            }
            
            enhancedContent += '\n\n\n\n';
            
            // Log usage
            logAIEnhancementUsage(contextData, aiModel);
            
            return enhancedContent;
            
        } catch (Exception e) {
            logAIEnhancementError(contextData, aiModel, e.getMessage());
            return baseContent;
        }
    }
    
    
    //======================================================
    // IDENTIFY AI PLACEHOLDER SECTIONS
    //======================================================
    private static List<String> identifyAISections(String content) {
        List<String> sections = new List<String>();
        
        if (content.containsIgnoreCase('{{ai_clause}}') || content.containsIgnoreCase('{ai_clause}')) {
            sections.add('ai_clause');
        }
        
        if (content.containsIgnoreCase('{{compliance_section}}') || content.containsIgnoreCase('{compliance_section}')) {
            sections.add('compliance_section');
        }
        
        return sections;
    }
    
    
    //======================================================
    // LOGGING – SUCCESS
    //======================================================
    private static void logAIEnhancementUsage(Map<String, Object> context, String aiModel) {
        try {
            Audit_Trail__c audit = new Audit_Trail__c(
                Action__c   = 'AI_ENHANCEMENT_USED',
                Details__c  = 'AI Model: ' + aiModel + ' | Context: ' + JSON.serialize(context).abbreviate(255),
                User__c     = UserInfo.getUserId(),
                CreatedDate__c = DateTime.now(),
                Record_Id__c = null
            );
            
            insert audit;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to log AI enhancement usage: ' + e.getMessage());
        }
    }
    
    
    //======================================================
    // LOGGING – ERROR
    //======================================================
    private static void logAIEnhancementError(Map<String, Object> context, String aiModel, String errorMessage) {
        try {
            Audit_Trail__c audit = new Audit_Trail__c(
                Action__c   = 'AI_ENHANCEMENT_ERROR',
                Details__c  = 'AI Model: ' + aiModel + ' | Error: ' + errorMessage.abbreviate(255),
                User__c     = UserInfo.getUserId(),
                CreatedDate__c = DateTime.now(),
                Record_Id__c = null
            );
            
            insert audit;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to log AI enhancement error: ' + e.getMessage());
        }
    }
    
    
    //======================================================
    // BACKWARD COMPATIBILITY (NO AI)
    //======================================================
    @AuraEnabled
    public static String assemble1(String templateContent, String mergeData) {
        return assemble(templateContent, mergeData, null);
    }
    
    
    //======================================================
    // TEMPLATE VALIDATION
    //======================================================
    @AuraEnabled
    public static Map<String, Object> validateTemplate(String templateContent) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('isValid', true);
        result.put('errors', new List<String>());
        
        try {
            Integer openBraces = 0;
            Integer closeBraces = 0;
            
            /*for (Integer i = 0; i < templateContent.length(); i++) {
if (templateContent.charAt(i) == '{') openBraces++;
if (templateContent.charAt(i) == '}') closeBraces++;
}*/
            
            if (openBraces != closeBraces) {
                ((List<String>) result.get('errors')).add('Unmatched braces in template');
                result.put('isValid', false);
            }
            
            result.put('mergeFieldsDetected', openBraces / 2);
            
        } catch (Exception e) {
            result.put('isValid', false);
            ((List<String>) result.get('errors')).add('Validation error: ' + e.getMessage());
        }
        
        return result;
    }
    /**
* @description Merges a template body with a map of data, replacing placeholders recursively.
* @param templateBody The HTML or text content of the template.
* @param data A map of data, which can include nested maps (e.g., 'contact', 'template').
* @return The merged content as a String.
*/
    // FIX: Method now returns a String and is static
    public static String merge1(String templateBody, Map<String, Object> data) {
        System.debug('templateBody:::'+templateBody);
        System.debug('data::::'+data);
        if (String.isBlank(templateBody) || data == null) {
            return templateBody;
        }
        
        String result = templateBody;
        
        // Iterate through the master data map to replace all placeholders
        for (String key : data.keySet()) {
            Object value = data.get(key);
            
            if (value instanceof Map<String, Object>) {
                // Nested object like 'template' or 'contact'
                Map<String, Object> nestedMap = (Map<String, Object>) value;
                
                // Handle nested placeholders such as {{template.Name}}
                for (String nestedKey : nestedMap.keySet()) {
                    String placeholder = '{{' + key + '.' + nestedKey + '}}';
                    Object nestedValue = nestedMap.get(nestedKey);
                    
                    // Replace null values with empty string
                    result = result.replace(
                        placeholder,
                        String.valueOf(nestedValue == null ? '' : nestedValue)
                    );
                }
            } else {
                // Simple placeholder like {{aiClause}}
                String placeholder = '{{' + key + '}}';
                result = result.replace(
                    placeholder,
                    String.valueOf(value == null ? '' : value)
                );
            }
        }
        
        return result;
    }
    
}