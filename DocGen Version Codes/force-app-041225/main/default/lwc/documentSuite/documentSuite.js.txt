import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Apex imports (kept same as originals)
import getDocumentTemplates from '@salesforce/apex/DocumentGenerationController.getDocumentTemplates';
import saveTemplate from '@salesforce/apex/DocumentGenerationController.saveTemplate';
import getActiveTemplatesForSelection from '@salesforce/apex/DocumentGenerationController.getActiveTemplatesForSelection';
import previewDocument from '@salesforce/apex/DocumentGenerationController.previewDocument';
import generateFinalDocument from '@salesforce/apex/DocumentGenerationController.generateFinalDocument';
import getDocumentDetailsForViewer from '@salesforce/apex/DocumentGenerationController.getDocumentDetailsForViewer';
import initiateSignatureRequest from '@salesforce/apex/SignatureRequestController.initiateSignatureRequest';

// Column definitions (renamed to avoid collision)
const TEMPLATE_COLS = [
    { label: 'Template Name', fieldName: 'Name', type: 'text', sortable: true },
    { label: 'Version', fieldName: 'Version__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Active', fieldName: 'IsActive__c', type: 'boolean' }
];

const AUDIT_COLS = [
    { label: 'Action', fieldName: 'Action__c' },
    { label: 'Details', fieldName: 'Details__c' },
    { label: 'Date', fieldName: 'CreatedDate', type: 'date' },
    { label: 'User', fieldName: 'UserName', type: 'text' }
];

export default class DocumentSuite extends NavigationMixin(LightningElement) {
    // Tab state
    @track activeTab = 'templates';

    // Template Manager state
    @track templates = [];
    @track selectedTemplate = {};
    @track isEditingTemplate = false;
    @track isLoadingTemplates = true;
    templateColumns = TEMPLATE_COLS;
    wiredTemplatesResult;

    // Generator state - we reuse the child component <c-document-generator> via events
    // Viewer state
    @track viewerRecordId = '';
    @track viewerIsLoading = false;
    @track viewerLoaded = false;
    @track documentTitle = '';
    @track renderedContent = '';
    @track signatureStatus = 'Not Sent';
    @track signatureMethod = 'N/A';
    @track signedDate;
    @track auditTrails = [];
    auditColumns = AUDIT_COLS;

    // Load templates for datatable
    @wire(getDocumentTemplates)
    wiredTemplates(result) {
        this.isLoadingTemplates = false;
        this.wiredTemplatesResult = result;
        if (result.data) {
            this.templates = result.data;
        } else if (result.error) {
            this.showToast('Error', 'Failed to load templates.', 'error');
        }
    }

    /* ===========================
       Template Manager handlers
       =========================== */
    handleTemplateRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length > 0) {
            // clone object to avoid mutation
            this.selectedTemplate = { ...selectedRows[0] };
            this.isEditingTemplate = true;
            // switch to Template tab just in case
            this.activeTab = 'templates';
        }
    }

    handleNewTemplate() {
        this.selectedTemplate = {
            sobjectType: 'DocumentTemplate__c',
            Name: 'New Employment Agreement',
            Body__c: '<h1>Employment Agreement</h1><p>This agreement is between {{contact.Name}} and our company.</p>',
            Version__c: 1,
            IsActive__c: false
        };
        this.isEditingTemplate = true;
        // clear selection in datatable (if present)
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = [];
        }
    }

    async handleTemplateSave(event) {
        // event.detail.template is expected from c-template-editor
        this.isLoadingTemplates = true;
        try {
            await saveTemplate({ templateRecord: event.detail.template });
            this.showToast('Success', 'Template saved successfully.', 'success');
            this.isEditingTemplate = false;
            this.selectedTemplate = {};
            await refreshApex(this.wiredTemplatesResult);
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Unknown error';
            this.showToast('Error', 'Failed to save template: ' + message, 'error');
        } finally {
            this.isLoadingTemplates = false;
        }
    }

    handleTemplateCancel() {
        this.isEditingTemplate = false;
        this.selectedTemplate = {};
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = [];
        }
    }

    /* ===========================
       Document Generator integration
       =========================== */
    // We use a child component <c-document-generator>; it will dispatch:
    // - 'successgenerate' with detail { recordId } when a doc is generated
    // - 'resetgenerator' when user wants to reset (optional)
    handleGeneratorSuccess(event) {
        const recordId = event.detail?.recordId;
        if (recordId) {
            // Navigate or load viewer tab automatically
            this.showToast('Success', 'Document generated: ' + recordId, 'success');
            // Set viewer id so user can view it immediately
            this.viewerRecordId = recordId;
            // switch to viewer tab
            this.activeTab = 'viewer';
            // load viewer details immediately
            this.loadDocumentForViewer();
        }
    }

    handleGeneratorReset() {
        // optional hook if generator wants to inform parent
        this.showToast('Ready', 'Generator reset.', 'info');
    }

    /* ===========================
       Document Viewer handlers
       =========================== */
    handleViewerRecordIdChange(event) {
        this.viewerRecordId = event.detail.value;
    }

    async loadDocumentForViewer() {
        if (!this.viewerRecordId) {
            this.showToast('Warning', 'Enter a record Id to load.', 'warning');
            return;
        }
        this.viewerIsLoading = true;
        this.viewerLoaded = false;
        try {
            const data = await getDocumentDetailsForViewer({ recordId: this.viewerRecordId });
            if (data) {
                this.documentTitle = data.document?.Name || '';
                this.renderedContent = data.renderedContent || '';
                if (data.signatureRequest) {
                    this.signatureStatus = data.signatureRequest.Status__c;
                    this.signatureMethod = data.signatureRequest.Signature_Method__c;
                    this.signedDate = data.signatureRequest.SignedDate__c;
                } else {
                    this.signatureStatus = 'Not Sent';
                    this.signatureMethod = 'N/A';
                    this.signedDate = null;
                }
                this.auditTrails = (data.auditTrails || []).map(row => ({ ...row, UserName: row.User__r ? row.User__r.Name : '' }));
                this.viewerLoaded = true;
            } else {
                this.showToast('Error', 'No data returned for this record.', 'error');
            }
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Unknown server error.';
            this.showToast('Error', message, 'error');
        } finally {
            this.viewerIsLoading = false;
        }
    }

    async handleRequestSignature() {
        try {
            const signatureRequestId = await initiateSignatureRequest({
                documentId: this.viewerRecordId,
                signerEmail: 'test.signer@example.com', // placeholder preserved from original
                documentTitle: this.documentTitle
            });
            this.showToast('Success', 'Signature request created successfully!', 'success');
            // navigate to the signature request if id returned
            if (signatureRequestId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: signatureRequestId,
                        objectApiName: 'Signature_Request__c',
                        actionName: 'view'
                    }
                });
            }
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Unknown error';
            this.showToast('Error', 'Failed to create signature request: ' + message, 'error');
        }
    }

    handleDownload() {
        this.showToast('Info', 'Download functionality is not yet implemented.', 'info');
    }

    /* ===========================
       Utility
       =========================== */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}