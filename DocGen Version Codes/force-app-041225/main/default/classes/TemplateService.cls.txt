public with sharing class TemplateService {

    // Create a template
    @AuraEnabled
    public static Id createTemplate(String name, String content, String format, Boolean isActive) {
        Template__c t = new Template__c();
        t.Name = name;
        t.Content__c = content;
        t.Format__c = format;
        t.IsActive__c = isActive;
        insert t;
        return t.Id;
    }

    // Update a template
    @AuraEnabled
    public static Template__c updateTemplate(Id templateId, String content, String format, Boolean isActive) {
        Template__c t = [
            SELECT Id, Content__c, Format__c, IsActive__c
            FROM Template__c
            WHERE Id = :templateId
            LIMIT 1
        ];
        t.Content__c = content;
        t.Format__c = format;
        t.IsActive__c = isActive;
        update t;
        return t;
    }

    // Get template by Id
    @AuraEnabled(cacheable = true)
    public static Template__c getTemplateById(Id id) {
        return [
            SELECT Id, Name, Content__c, Format__c, Version__c, IsActive__c
            FROM Template__c
            WHERE Id = :id
            LIMIT 1
        ];
    }

    // List templates
    @AuraEnabled(cacheable = true)
    public static List<Template__c> listTemplates(Boolean onlyActive) {
        if (onlyActive) {
            return [
                SELECT Id, Name, Format__c, Version__c, IsActive__c
                FROM Template__c
                WHERE IsActive__c = true
                ORDER BY Name
            ];
        } else {
            return [
                SELECT Id, Name, Format__c, Version__c, IsActive__c
                FROM Template__c
                ORDER BY Name
            ];
        }
    }

    // Soft delete template
    @AuraEnabled
    public static void deleteTemplate(Id id) {
        Template__c t = new Template__c(Id = id);
        delete t;
    }

    // Simple versioning helper - create new version copy
    @AuraEnabled
    public static Id createTemplateVersion(Id existingTemplateId, String newContent) {
        // Load the template
        Template__c t = [
            SELECT Name, Content__c, Format__c, Version__c
            FROM Template__c
            WHERE Id = :existingTemplateId
            LIMIT 1
        ];

        // Clone to create a new version record
        Template__c v = t.clone(false, true, false, false);
        v.Content__c = newContent;

        // Compute next version as Integer (defensive parsing)
        Integer nextVersion = 1;
        try {
            String current = String.valueOf(t.Version__c);
            if (current != null && current != 'null' && !String.isBlank(current)) {
                try {
                    nextVersion = Integer.valueOf(current) + 1;
                } catch (Exception pe) {
                    // parsing failed -- fallback to 1
                    nextVersion = 1;
                }
            } else {
                nextVersion = 1;
            }
        } catch (Exception e) {
            nextVersion = 1;
        }

        // Detect Version__c field type dynamically
        Schema.DescribeFieldResult dfr = Template__c.Version__c.getDescribe();
        Schema.DisplayType fdType = dfr.getType();

        SObject so = (SObject) v;
        if (fdType == Schema.DisplayType.INTEGER
            || fdType == Schema.DisplayType.DOUBLE
            || fdType == Schema.DisplayType.CURRENCY
            || fdType == Schema.DisplayType.PERCENT) {
            so.put('Version__c', nextVersion);
        } else {
            // write as string when field is text-based
            so.put('Version__c', String.valueOf(nextVersion));
        }

        insert v;
        return v.Id;
    }
}