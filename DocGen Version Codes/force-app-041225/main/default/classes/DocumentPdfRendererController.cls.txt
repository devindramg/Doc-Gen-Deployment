/**
 * Controller used by Visualforce page DocumentPdfRenderer2.
 * It loads the ContentVersion by Id from the 'cvId' parameter
 * and exposes the HTML content for rendering as PDF.
 */
public with sharing class DocumentPdfRendererController {
    public String htmlContent { get; private set; }

    public DocumentPdfRendererController() {
        htmlContent = '';
        String cvId = ApexPages.currentPage().getParameters().get('cvId');
        if (String.isBlank(cvId)) {
            htmlContent = '<p>No content version id provided.</p>';
            return;
        }
        try {
            ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE Id = :cvId LIMIT 1];
            if (cv != null && cv.VersionData != null) {
                htmlContent = cv.VersionData.toString();
            } else {
                htmlContent = '<p>ContentVersion has no data.</p>';
            }
        } catch (Exception e) {
            htmlContent = '<p>Error loading content: ' + String.escapeHtml4(e.getMessage()) + '</p>';
        }
    }
}
