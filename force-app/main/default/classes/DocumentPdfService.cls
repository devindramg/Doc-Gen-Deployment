/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-04-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class DocumentPdfService {

    /**
     * Save HTML to a temporary ContentVersion and return its Id.
     * Then you can render the VF page: Page.DocumentPdfRenderer2 + '?cvId=' + contentVersionId
     */
    public static Id saveHtmlAsContentVersion(String htmlContent, String title) {
        if (String.isBlank(title)) title = 'temp_doc_' + Datetime.now().getTime();
        // Ensure extension .html
        String fileName = title;
        if (!fileName.toLowerCase().endsWith('.html')) {
            fileName += '.html';
        }

        ContentVersion cv = new ContentVersion();
        cv.Title = title;
        cv.PathOnClient = fileName;
        // VersionData expects blob - use UTF-8
        cv.VersionData = Blob.valueOf(htmlContent);
        cv.IsMajorVersion = true;

        insert cv;
        return cv.Id;
    }

    /**
     * Render the saved ContentVersion Id to a PDF Blob using VF page that loads the CV by Id.
     * Returns the Blob (PDF) — caller can insert ContentVersion with that blob as .pdf.
     */
    public static Blob renderContentVersionToPdf(Id contentVersionId) {
        // Build PageReference to VF page that reads ContentVersion by Id
        // Use dynamic PageReference to avoid compile-time dependency on the Page metadata
        PageReference pdfPage = new PageReference('/apex/DocumentPdfRenderer2');
        pdfPage.getParameters().put('cvId', String.valueOf(contentVersionId));
        // getContentAsPDF will render page as PDF
        Blob pdfBlob = pdfPage.getContentAsPDF();
        return pdfBlob;
    }

    /**
     * Convenience: save HTML and return PDF Blob
     */
    public static Blob saveHtmlAndRenderPdf(String htmlContent, String title) {
        Id cvId = saveHtmlAsContentVersion(htmlContent, title);
        Blob pdf = renderContentVersionToPdf(cvId);
        return pdf;
    }
}
