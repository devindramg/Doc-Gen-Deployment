/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-03-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class OpenAIService {
    private static final String NAMED_CREDENTIAL = 'OpenAI_NC'; // update if different

    public class OpenAIResponse {
        public String id;
        public String objectType;
        public List<Choice> choices;
    }

    public class Choice {
        public Integer index;
        public Message message;
        public String text; // older APIs
    }

    public class Message {
        public String role;
        public String content;
    }

    /**
     * Simple chat completion call. Adjust path and body to your provider.
     * modelId: pass model identifier
     * prompt: text prompt
     */
    @AuraEnabled
    public static String getCompletion(String modelId, String prompt) {
        try {
            HttpRequest req = new HttpRequest();
            // Using Named Credential - URL is from named credential
            // For OpenAI, endpoint might be: /v1/chat/completions
            req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/v1/chat/completions');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');

            // Compose body based on provider API. This example uses chat completion structure.
            Map<String, Object> body = new Map<String, Object>{
                'model' => modelId,
                'messages' => new List<Object>{
                    new Map<String, Object>{ 'role' => 'system', 'content' => 'You are a legal drafting assistant. Produce concise legal clauses.' },
                    new Map<String, Object>{ 'role' => 'user', 'content' => prompt }
                },
                'temperature' => 0.0,
                'max_tokens' => 1200
            };

            req.setBody(JSON.serialize(body));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                // Parse response - extract the assistant message
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if (parsed.containsKey('choices')) {
                    List<Object> choices = (List<Object>) parsed.get('choices');
                    if (!choices.isEmpty()) {
                        Map<String, Object> choice0 = (Map<String, Object>) choices[0];
                        if (choice0.containsKey('message')) {
                            Map<String, Object> message = (Map<String, Object>) choice0.get('message');
                            return (String) message.get('content');
                        } else if (choice0.containsKey('text')) {
                            return (String) choice0.get('text');
                        }
                    }
                }
                return res.getBody();
            } else {
                throw new AuraHandledException('AI provider returned error: ' + res.getStatusCode() + ' ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException('OpenAI callout failed: ' + e.getMessage());
        }
    }
}