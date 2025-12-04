import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getDocumentsForViewer from '@salesforce/apex/DocumentGenerationController.getDocumentsForViewer';
import getDocumentDetailsForViewer from '@salesforce/apex/DocumentGenerationController.getDocumentDetailsForViewer';
import initiateSignatureRequest from '@salesforce/apex/SignatureRequestController.initiateSignatureRequest';

const AUDIT_COLS = [
    { label: 'Action', fieldName: 'Action__c' },
    { label: 'Details', fieldName: 'Details__c', wrapText: true },
    {
        label: 'Date',
        fieldName: 'CreatedDate',
        type: 'date',
        typeAttributes: {
            month: 'short',
            day: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    { label: 'User', fieldName: 'UserName', type: 'text' }
];

export default class DocumentViewer extends NavigationMixin(LightningElement) {
    @api recordId;

    // List of documents
    @track documentRows = [];

    // Selected document
    @track selectedDocumentId;
    @track showModal = false;

    // Loading
    @track isLoading = false;

    // Viewer fields
    @track documentTitle = 'Document Viewer';
    @track renderedContent;
    @track contentDocumentId;

    // Signature
    @track hasSignatureRequest = false;
    @track signatureStatus;
    @track signatureMethod;
    @track signedDate;

    // Audit Trail
    @track auditTrails;
    columns = AUDIT_COLS;

    // Load available documents
    @wire(getDocumentsForViewer)
    wiredDocs({ data, error }) {
        if (data) {
            this.documentRows = data;
        } else if (error) {
            this.showToast(
                'Error',
                'Failed to load documents: ' + (error.body && error.body.message),
                'error'
            );
        }
    }

    // Radio button selection
    handleDocSelect(event) {
        this.selectedDocumentId = event.target.value;
        this.openModal();
    }

    // Load selected document
    async openModal() {
        if (!this.selectedDocumentId) {
            return;
        }

        this.showModal = true;
        this.isLoading = true;

        try {
            const data = await getDocumentDetailsForViewer({
                recordId: this.selectedDocumentId
            });

            this.documentTitle = data.document.Name;
            this.renderedContent = data.renderedContent;
            this.contentDocumentId = data.document.ContentDocumentString__c;

            // Signature Details
            if (data.signatureRequest) {
                this.hasSignatureRequest = true;
                this.signatureStatus = data.signatureRequest.Status__c;
                this.signatureMethod = data.signatureRequest.Signature_Method__c;
                this.signedDate = data.signatureRequest.SignedDate__c;
            } else {
                this.hasSignatureRequest = false;
                this.signatureStatus = null;
                this.signatureMethod = null;
                this.signedDate = null;
            }

            // Audit Trail
            if (data.auditTrails && data.auditTrails.length > 0) {
                this.auditTrails = data.auditTrails.map(row => ({
                    ...row,
                    UserName:
                        row.User__r && row.User__r.Name ? row.User__r.Name : 'System'
                }));
            } else {
                this.auditTrails = null;
            }
        } catch (error) {
            this.showToast(
                'Error',
                'Failed to load document details: ' +
                    (error.body && error.body.message),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    // Create signature request
    async handleRequestSignature() {
        if (!this.selectedDocumentId) {
            this.showToast('Action Required', 'Please select a document first.', 'warning');
            return;
        }

        const signerEmail = 'test.signer@example.com';

        this.isLoading = true;

        try {
            const signatureRequestId = await initiateSignatureRequest({
                documentConfigId: this.selectedDocumentId,
                signerEmail: signerEmail,
                documentTitle: this.documentTitle
            });

            this.showToast('Success', 'Signature request created successfully!', 'success');

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: signatureRequestId,
                    objectApiName: 'Signature_Request__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showToast(
                'Error',
                'Failed to create signature request: ' +
                    (error.body && error.body.message),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    // Download File
    handleDownload() {
        if (this.contentDocumentId) {
            const downloadUrl =
                '/sfc/servlet.shepherd/document/download/' + this.contentDocumentId;
            window.open(downloadUrl, 'blank');
        } else {
            this.showToast('Error', 'No document file found to download.', 'error');
        }
    }

    // Close Modal
    closeModal() {
        this.showModal = false;
    }

    // Toast
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}