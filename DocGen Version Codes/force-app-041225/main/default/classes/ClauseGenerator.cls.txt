/**
 * @description  AI-powered clause generator with proper Apex syntax
 *               Handles clause generation, AI enhancement, and audit logging
 * @version      2.1
 * @author       Anara AI
 * @last modified on : 11-25-2025
 */
public with sharing class ClauseGenerator {

    // =====================================================
    // STATIC CLAUSE TEMPLATES (Region + Contract Type)
    // =====================================================
    private static final Map<String, Map<String, String>> CLAUSE_TEMPLATES =
        new Map<String, Map<String, String>>{
            'US' => new Map<String, String>{
                'Employment' =>
                    'This employment agreement is governed by the laws of the United States. '
                    + 'The employee acknowledges that they are an at-will employee and that employment may be '
                    + 'terminated by either party with or without cause.',

                'NDA' =>
                    'This Non-Disclosure Agreement is governed by United States federal and state laws. '
                    + 'The receiving party agrees to maintain strict confidentiality of all disclosed information '
                    + 'for a period of five (5) years from the date of disclosure.',

                'SLA' =>
                    'This Service Level Agreement establishes performance standards and remedies under United States commercial law. '
                    + 'Service provider guarantees 99.9% uptime with penalties for non-compliance.'
            },

            'EU' => new Map<String, String>{
                'Employment' =>
                    'This employment contract complies with European Union employment directives and GDPR requirements. '
                    + 'The employee has the right to data portability and erasure under GDPR Article 17.',

                'NDA' =>
                    'This Non-Disclosure Agreement is GDPR-compliant and respects data subject rights under EU law. '
                    + 'Personal data processing is limited to legitimate business interests.',

                'SLA' =>
                    'This Service Level Agreement complies with EU Digital Services Act & GDPR requirements. '
                    + 'Data processing activities are documented and data subjects retain full rights under GDPR.'
            },

            'APAC' => new Map<String, String>{
                'Employment' =>
                    'This employment agreement is subject to local labor laws in the Asia-Pacific region. '
                    + 'The employee acknowledges compliance with local data protection laws.',

                'NDA' =>
                    'This Non-Disclosure Agreement respects privacy and data protection laws in the APAC region. '
                    + 'Confidential information is protected according to local standards.',

                'SLA' =>
                    'This Service Level Agreement complies with regional technology and data localization requirements. '
                    + 'Service delivery meets applicable local standards.'
            }
        };

    // =====================================================
    // ROLE-SPECIFIC CLAUSE ADDITIONS
    // =====================================================
    private static final Map<String, String> ROLE_SPECIFIC_CLAUSES =
        new Map<String, String>{
            'Manager' =>
                '\n\nMANAGEMENT PROVISIONS:\n'
                + '- Authorized signatory privileges\n'
                + '- Performance management duties\n'
                + '- Budget oversight responsibilities',

            'Employee' =>
                '\n\nEMPLOYEE OBLIGATIONS:\n'
                + '- Follow company policies\n'
                + '- Training participation\n'
                + '- Team collaboration',

            'Developer' =>
                '\n\nTECHNICAL RESPONSIBILITIES:\n'
                + '- Code quality and best practices\n'
                + '- IP assignment for developed software\n'
                + '- Compliance with security policies',

            'Contractor' =>
                '\n\nCONTRACTOR PROVISIONS:\n'
                + '- Independent contractor status\n'
                + '- Deliverable timelines\n'
                + '- Liability limitations'
        };

    // =====================================================
    // MAIN METHOD – GENERATE CLAUSE
    // =====================================================
    /**
     * @description Generates a clause with optional AI enhancement
     * @param region
     * @param role
     * @param contractType
     * @param aiModelIdentifier
     */
    @AuraEnabled
    public static String generateClause(
        String region,
        String role,
        String contractType,
        String aiModelIdentifier
    ) {
        try {
            if (String.isBlank(region) ||
                String.isBlank(role) ||
                String.isBlank(contractType)) {
                throw new AuraHandledException('All parameters (region, role, contractType) are required.');
            }

            String baseClause = getBaseClause(region, contractType);
            if (String.isBlank(baseClause)) {
                throw new AuraHandledException(
                    'No template found for Region: ' + region + ', Contract Type: ' + contractType
                );
            }

            String roleClause = ROLE_SPECIFIC_CLAUSES.get(role);
            if (roleClause == null) {
                roleClause =
                    '\n\nGENERAL PROVISIONS:\n'
                    + '- Standard terms and conditions apply';
            }

            String fullClause = baseClause + roleClause;

            if (String.isNotBlank(aiModelIdentifier)) {
                fullClause = enhanceWithAI(
                    fullClause,
                    region,
                    role,
                    contractType,
                    aiModelIdentifier
                );
            }

            logClauseGeneration(region, role, contractType, aiModelIdentifier, fullClause, 'SUCCESS');

            return fullClause;
        } catch (Exception e) {
            logClauseGeneration(region, role, contractType, aiModelIdentifier, e.getMessage(), 'ERROR');
            throw new AuraHandledException('Clause generation failed: ' + e.getMessage());
        }
    }

    // =====================================================
    // SUPPORT METHOD FOR OTHER CONTROLLERS
    // =====================================================
    /**
     * @description Logs an AI suggestion action for other controllers.
     */
    public static void logAIGeneration(
        String modelId,
        String prompt,
        String response,
        String status,
        String errorMessage
    ) {
        try {
            String details = 'AI Model: ' + modelId + ' | Prompt: ' + prompt;
            system.debug('errorMessage::::'+errorMessage);
            if (String.isNotBlank(errorMessage)) {
                details += ' | Error: ' + errorMessage;
            } else if (String.isNotBlank(response)) {
                details += ' | Response Snippet: ' + response.abbreviate(200);
            }
            system.debug('details::::'+details);
            Audit_Trail__c audit = new Audit_Trail__c(
                Action__c = (status == 'Success')
                ? 'AI_CLAUSE_SUGGESTION'
                : 'AI_SUGGESTION_ERROR',
                Details__c = details,
                User__c = UserInfo.getUserId(),
                Status__c = status
            );
            system.debug('audit:::::'+audit);
            insert audit;
            system.debug('audit::::Id::::'+audit.id);
        } catch (Exception e) {
            System.debug('Could not log AI clause suggestion: ' + e.getMessage());
        }
    }

    // =====================================================
    // HELPER – GET BASE CLAUSE TEMPLATE
    // =====================================================
    private static String getBaseClause(String region, String contractType) {
        if (CLAUSE_TEMPLATES.containsKey(region) &&
            CLAUSE_TEMPLATES.get(region).containsKey(contractType)) {
            return CLAUSE_TEMPLATES.get(region).get(contractType);
        }

        return 'This ' + contractType.toLowerCase()
            + ' agreement is subject to standard terms and conditions.';
    }

    // =====================================================
    // HELPER – AI ENHANCEMENT
    // =====================================================
    private static String enhanceWithAI(
        String baseClause,
        String region,
        String role,
        String contractType,
        String aiModelIdentifier
    ) {
        try {
            AIModelManager.AIModelConfig config = AIModelManager.getAIModelByIdentifier(aiModelIdentifier);

            if (config == null || !config.isActive) {
                return baseClause;
            }

            String enhanced = baseClause;

            enhanced += '\n\nThis agreement incorporates regulatory requirements as of '
                        + Date.today().format() + '.';

            if (role == 'Manager' || role == 'Developer') {
                enhanced += '\n\nSECURITY PROVISIONS: Enhanced MFA, security training, '
                            + 'and compliance required.';
            }

            if (region == 'EU') {
                enhanced += '\n\nDATA RESIDENCY: Data stored within EU boundaries unless '
                            + 'approved transfer mechanisms apply.';
            }

            return enhanced;
        } catch (Exception e) {
            return baseClause;
        }
    }

    // =====================================================
    // AUDIT LOGGING
    // =====================================================
    private static void logClauseGeneration(
        String region,
        String role,
        String contractType,
        String aiModel,
        String result,
        String status
    ) {
        try {
            Audit_Trail__c audit = new Audit_Trail__c(
                Action__c = (status == 'SUCCESS')
                    ? 'CLAUSE_GENERATED'
                    : 'CLAUSE_GENERATION_ERROR',
                Details__c =
                    'Region: ' + region
                    + ' | Role: ' + role
                    + ' | Type: ' + contractType
                    + (String.isNotBlank(aiModel)
                        ? ' | AI Model: ' + aiModel
                        : ''),
                User__c = UserInfo.getUserId(),
                Status__c = status
            );

            insert audit;
        } catch (Exception e) {
            System.debug('Could not log clause generation: ' + e.getMessage());
        }
    }

    // =====================================================
    // GENERATE VARIATIONS
    // =====================================================
    @AuraEnabled
    public static List<String> generateClauseVariations(
        String region,
        String role,
        String contractType,
        Integer variationCount,
        String aiModelIdentifier
    ) {
        List<String> results = new List<String>();

        if (variationCount == null || variationCount <= 0) {
            variationCount = 3;
        }

        String baseClause = generateClause(region, role, contractType, aiModelIdentifier);
        results.add(baseClause);

        for (Integer i = 1; i < variationCount; i++) {
            results.add(generateClauseVariation(baseClause, i));
        }

        return results;
    }

    // =====================================================
    // INDIVIDUAL VARIATION GENERATOR
    // =====================================================
    private static String generateClauseVariation(String baseClause, Integer type) {
        String variation = baseClause;

        switch on type {
            when 1 {
                variation = variation.replace('you acknowledge', 'the party acknowledges');
                variation = variation.replace('You agree', 'The party agrees');
                variation += '\n\nFORMAL ADDENDUM: This agreement is the full understanding between parties.';
            }
            when 2 {
                variation +=
                    '\n\nDETAILED PROVISIONS: Includes performance metrics, compliance checkpoints, '
                    + 'and regular reviews.';
            }
            when else {
                variation +=
                    '\n\nIMPLEMENTATION NOTE: All provisions take effect immediately upon signature.';
            }
        }

        return variation;
    }
}