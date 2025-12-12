/**
* @description   Manages AI model configurations and orchestrates AI processing requests.
*                Acts as the central hub for retrieving available models and routing
*                generation/analysis requests to the appropriate provider (Einstein, OpenAI, etc.).
* @author        Anara AI
* @version       3.1
* @last modified 11-25-2025
*/

public with sharing class AIModelManager {
    
    //======================================================
    // DTO WRAPPER CLASS FOR AI MODELS
    //======================================================
    public class AIModelConfig {
        
        @AuraEnabled public String modelName        { get; set; }
        @AuraEnabled public String modelIdentifier  { get; set; }
        @AuraEnabled public String provider         { get; set; }
        @AuraEnabled public String capabilities     { get; set; }
        @AuraEnabled public Boolean isActive        { get; set; }   // Added for ClauseGenerator checks
        
        // Construct from Custom Metadata record
        public AIModelConfig(AI_Model_Configuration__mdt config) {
            this.modelName       = config.ModelName__c;
            this.modelIdentifier = config.Model_Id__c;
            this.provider        = config.Provider__c;
            this.capabilities    = config.Capabilities__c;
            this.isActive        = config.Is_Active__c;
        }
        
        // Construct for hardcoded native Einstein models
        public AIModelConfig(String name, String identifier, String provider, String capabilities) {
            this.modelName       = name;
            this.modelIdentifier = identifier;
            this.provider        = provider;
            this.capabilities    = capabilities;
            this.isActive        = true;     // Native models are always active
        }
    }
    
    //======================================================
    // GET AVAILABLE AI MODELS (for UI dropdown)
    //======================================================
    @AuraEnabled(cacheable=true)
    public static List<AIModelConfig> getAvailableAIModels() {
        List<AIModelConfig> models = new List<AIModelConfig>();
        
        try {
            // From Custom Metadata
            for (AI_Model_Configuration__mdt config :
                 [SELECT ModelName__c, Model_Id__c, Provider__c, Capabilities__c, Is_Active__c
                  FROM AI_Model_Configuration__mdt
                  WHERE Is_Active__c = true
                  ORDER BY ModelName__c]
                ) {
                    models.add(new AIModelConfig(config));
                }
            
            // Add hardcoded Einstein models
            models.add(new AIModelConfig('Einstein Intent Detection',
                                         'einstein_intent',
                                         'Salesforce',
                                         'Intent Analysis, Classification'));
            
            models.add(new AIModelConfig('Einstein Sentiment Analysis',
                                         'einstein_sentiment',
                                         'Salesforce',
                                         'Sentiment Analysis, Emotion Detection'));
            
            models.add(new AIModelConfig('Einstein OCR',
                                         'einstein_ocr',
                                         'Salesforce',
                                         'Text Extraction, Document Parsing'));
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                         'Error retrieving AI models: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve AI models: ' + e.getMessage());
        }
        
        return models;
    }
    
    //======================================================
    // GET AI MODEL BY IDENTIFIER (Used by ClauseGenerator)
    //======================================================
    /**
* @description   Finds an AI model by its unique identifier.
* @param         modelIdentifier
* @return        AIModelConfig or null
*/
    public static AIModelConfig getAIModelByIdentifier(String modelIdentifier) {
        if (String.isBlank(modelIdentifier)) {
            return null;
        }
        
        for (AIModelConfig model : getAvailableAIModels()) {
            if (model.modelIdentifier == modelIdentifier) {
                return model;
            }
        }
        
        return null;  // Model not found
    }
    
    //======================================================
    // MAIN AI PROCESSING ROUTER
    //======================================================
    @AuraEnabled
    public static String processWithEinstein(String modelId, String prompt, String context) {
        try {
            AI_Model_Configuration__mdt modelConfig = getModelConfiguration(modelId);
            system.debug('modelConfig::::'+modelConfig);
            System.debug('modelConfig != null:::::'+modelConfig != null);
            if (modelConfig != null) {
                system.debug('modelConfig.Model_Provider__c:::::'+modelConfig.Model_Provider__c);
                if (modelConfig.Model_Provider__c == 'einstein_intent') {
                    System.debug('inside if condition::::');
                    return processWithEinsteinNative(prompt, context, modelConfig);
                } else if (modelConfig.Model_Provider__c == 'OpenAI') {
                    throw new AIProcessingException('OpenAI provider not yet implemented.');
                    
                } else {
                    throw new AIProcessingException('Unsupported model provider: ' +
                                                    modelConfig.Model_Provider__c);
                }
                
            } else if (modelId.startsWith('einstein_')) {
                return processWithEinsteinNative(prompt, context, null);
            }
            
            throw new AIProcessingException('Model configuration not found for ID: ' + modelId);
            
        } catch (Exception e) {
            throw new AuraHandledException('AI processing failed: ' + e.getMessage());
        }
    }
    
    //======================================================
    // EINSTEIN PLATFORM SERVICES INTEGRATION
    //======================================================
  private static String processWithEinsteinNative(
    String prompt,
    String context,
    AI_Model_Configuration__mdt config
) {
    System.debug('prompt::::' + prompt);
    System.debug('context:::' + context);
    System.debug('config::::' + config);

    // ✅ TOGGLE MODE
    if (config != null) {
        System.debug('Using HARDCODED AI response');
// ✅ Hardcoded Employment Agreement Clause Block
    String aiClause =
        '1. Employment Terms\n'
      + 'The Employee shall serve the Employer in the role of Individual Contributor and shall perform all duties assigned in accordance with company policies.\n\n'

      + '2. Compensation & Benefits\n'
      + 'The Employee shall receive compensation and benefits as per the Employer’s standard payroll and benefit structure applicable in North America.\n\n'

      + '3. Working Hours\n'
      + 'The Employee shall adhere to standard working hours as defined by the Employer and applicable labor laws.\n\n'

      + '4. Confidentiality\n'
      + 'The Employee agrees to maintain strict confidentiality of all proprietary, business, and client information during and after the term of employment.\n\n'

      + '5. Intellectual Property\n'
      + 'Any intellectual property created during employment shall be the exclusive property of the Employer.\n\n'

      + '6. Termination\n'
      + 'Either party may terminate this Agreement by providing 30 days written notice or as per applicable law.\n\n'

      + '7. Governing Law\n'
      + 'This Agreement shall be governed by and construed in accordance with the laws applicable in North America.\n\n'

      + '8. Entire Agreement\n'
      + 'This document constitutes the entire agreement between the parties and supersedes all prior understandings.';

    return aiClause;

    }

    // ✅ REAL API CALL ONLY IF TOGGLE IS OFF
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:OpenAI/v1/chat/completions'); 
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');

    Map<String, Object> body = new Map<String, Object>{
        'model' => 'gpt-4o-mini',
        'messages' => new List<Object>{
            new Map<String, Object>{
                'role' => 'user',
                'content' => prompt + '\n\nContext:\n' + context
            }
        }
    };

    req.setBody(JSON.serialize(body));

    Http http = new Http();
    HttpResponse response = http.send(req);

    System.debug('STATUS CODE: ' + response.getStatusCode());
    System.debug('RAW RESPONSE: ' + response.getBody());

    if (response.getStatusCode() == 200) {
        Map<String, Object> result =
            (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

        List<Object> choices = (List<Object>) result.get('choices');
        Map<String, Object> firstChoice =
            (Map<String, Object>) choices[0];
        Map<String, Object> message =
            (Map<String, Object>) firstChoice.get('message');

        return (String) message.get('content');
    }

    throw new AIProcessingException(
        'OpenAI API failed with status ' +
        response.getStatusCode() +
        ' | Response: ' + response.getBody()
    );
}

    
    
    //======================================================
    // HELPER METHODS
    //======================================================
    private static AI_Model_Configuration__mdt getModelConfiguration(String modelId) {
        system.debug('modelId:::::'+modelId);
        List<AI_Model_Configuration__mdt> configs =
            [SELECT DeveloperName, Model_Id__c, ModelName__c, Provider__c,
             API_Endpoint__c, Max_Tokens__c, Is_Active__c, Capabilities__c,Model_Provider__c
             FROM AI_Model_Configuration__mdt
             WHERE DeveloperName = :modelId LIMIT 1];
        
        return configs.isEmpty() ? null : configs[0];
    }
    
    private static String getEinsteinAccessToken() {
        return 'temp_einstein_access_token';
    }
    
    //======================================================
    // CUSTOM EXCEPTION
    //======================================================
    public class AIProcessingException extends Exception {}
}