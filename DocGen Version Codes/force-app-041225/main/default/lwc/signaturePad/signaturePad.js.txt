import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Apex Methods
import getSignatureRequests from '@salesforce/apex/SignatureRequestController.getSignatureRequests';
import getSignatureRequest from '@salesforce/apex/SignatureRequestController.getSignatureRequest';
import submitSignature from '@salesforce/apex/SignatureRequestController.submitSignature';

// --- UPDATED COLUMNS DEFINITION ---
const COLUMNS = [
    { label: 'Request Number', fieldName: 'Name', type: 'text' }, // Added this line
    { label: 'Document Title', fieldName: 'DocumentTitle__c', type: 'text' },
    { label: 'Signer Name', fieldName: 'SignerName__c', type: 'text' },
    { label: 'Signer Email', fieldName: 'SignerEmail__c', type: 'email' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Request Date', fieldName: 'RequestDate__c', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' } },
    { label: 'OTP Verified', fieldName: 'OTP_Verification__c', type: 'boolean' }
];

export default class SignaturePad extends LightningElement {
    // View Management
    @track showListView = true;
    @track showSignatureView = false;
    @track isLoading = true;
    @track isSubmitting = false;

    // Datatable Properties
    @track columns = COLUMNS;
    @track requests;
    wiredRequestsResult;

    // Signature Pad Properties
    @track selectedRequestId;
    @track documentTitle = '';
    @track selectedMethod = 'draw';
    @track typedSignature = '';
    @track drawnSignatureData = '';
    @track uploadedSignature = '';
    @track signerEmail = '';
    @track signerName = '';
    @track termsAccepted = false;

    // Canvas Drawing Properties
    isDrawing = false;
    canvas;
    ctx;
    lastX = 0;
    lastY = 0;

    // --- WIRED APEX ---
    @wire(getSignatureRequests)
    wiredRequests(result) {
        this.wiredRequestsResult = result;
        if (result.data) {
            this.requests = result.data;
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error', 'Failed to load signature requests.', 'error');
            this.isLoading = false;
        }
    }

    // --- VIEW MANAGEMENT & NAVIGATION ---
    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length > 0) {
            this.selectedRequestId = selectedRows[0].Id;
            this.switchToSignatureView();
        }
    }

    switchToSignatureView() {
        if (!this.selectedRequestId) return;
        this.isLoading = true;
        getSignatureRequest({ requestId: this.selectedRequestId })
            .then(result => {
                this.documentTitle = result.documentTitle;
                this.signerEmail = result.signerEmail || '';
                this.signerName = result.signerName || '';

                // Switch views
                this.showListView = false;
                this.showSignatureView = true;
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load signature request details.', 'error');
                this.isLoading = false;
            });
    }

    handleBackToList() {
        this.showSignatureView = false;
        this.showListView = true;
        this.resetSignatureData();
    }

    // --- SIGNATURE PAD GETTERS ---
    get signatureMethodOptions() {
        return [
            { label: 'Draw Signature', value: 'draw' },
            { label: 'Type Name', value: 'type' },
            { label: 'Upload Image', value: 'upload' }
        ];
    }

    get isTypeMethod() { return this.selectedMethod === 'type'; }
    get isDrawMethod() { return this.selectedMethod === 'draw'; }
    get isUploadMethod() { return this.selectedMethod === 'upload'; }

    get hasValidSignature() {
        switch (this.selectedMethod) {
            case 'type': return this.typedSignature && this.typedSignature.trim().length > 0;
            case 'draw': return this.drawnSignatureData && this.drawnSignatureData.length > 0;
            case 'upload': return this.uploadedSignature && this.uploadedSignature.length > 0;
            default: return false;
        }
    }

    get isSubmitDisabled() {
        return !this.termsAccepted || !this.signerName || !this.signerEmail || !this.hasValidSignature || this.isSubmitting;
    }

    // --- SIGNATURE PAD EVENT HANDLERS ---
    renderedCallback() {
        if (this.isDrawMethod && this.showSignatureView && !this.canvas) {
            this.initializeCanvas();
        }
    }

    initializeCanvas() {
        this.canvas = this.template.querySelector('.signature-canvas');
        if (this.canvas) {
            this.ctx = this.canvas.getContext('2d');
            this.canvas.addEventListener('mousedown', this.startDrawing.bind(this));
            this.canvas.addEventListener('mousemove', this.draw.bind(this));
            this.canvas.addEventListener('mouseup', this.stopDrawing.bind(this));
            this.canvas.addEventListener('mouseout', this.stopDrawing.bind(this));
        }
    }

    handleMethodChange(event) { this.selectedMethod = event.detail.value; }
    handleTypedSignatureChange(event) { this.typedSignature = event.target.value; }
    handleSignerNameChange(event) { this.signerName = event.target.value; }
    handleSignerEmailChange(event) { this.signerEmail = event.target.value; }
    handleTermsChange(event) { this.termsAccepted = event.target.checked; }

    // --- CANVAS DRAWING METHODS ---
    startDrawing(event) {
        this.isDrawing = true;
        [this.lastX, this.lastY] = [event.offsetX, event.offsetY];
    }

    draw(event) {
        if (!this.isDrawing) return;
        this.ctx.beginPath();
        this.ctx.moveTo(this.lastX, this.lastY);
        this.ctx.lineTo(event.offsetX, event.offsetY);
        this.ctx.stroke();
        [this.lastX, this.lastY] = [event.offsetX, event.offsetY];
    }

    stopDrawing() {
        if (this.isDrawing) {
            this.isDrawing = false;
            this.drawnSignatureData = this.canvas.toDataURL('image/png');
        }
    }

    clearCanvas() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        this.drawnSignatureData = '';
    }

    // --- UPLOAD METHOD ---
    handleUploadFinished(event) {
        if (event.detail.files.length > 0) {
            const reader = new FileReader();
            reader.onload = () => { this.uploadedSignature = reader.result; };
            reader.readAsDataURL(event.detail.files[0]);
            this.showToast('Success', 'Signature uploaded successfully', 'success');
        }
    }

    // --- SUBMIT LOGIC ---
    async handleSubmitSignature() {
        if (this.isSubmitDisabled) return;
        this.isSubmitting = true;
        try {
            const signatureData = this.getSignatureData();
            const signerInfo = JSON.stringify({
                signatureMethod: this.selectedMethod,
                signerName: this.signerName,
                signerEmail: this.signerEmail,
                timestamp: new Date().toISOString()
            });

            await submitSignature({
                requestId: this.selectedRequestId,
                signatureData: signatureData,
                signerInfo: signerInfo
            });

            this.showToast('Success', 'Signature submitted successfully!', 'success');
            this.handleBackToList();

            this.isLoading = true; // Show spinner while refreshing list
            refreshApex(this.wiredRequestsResult).finally(() => { this.isLoading = false; });

        } catch (error) {
            const errorMessage = error.body ? error.body.message : error.message;
            this.showToast('Error', 'Failed to submit signature: ' + errorMessage, 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    getSignatureData() {
        switch (this.selectedMethod) {
            case 'type': return `data:text/plain;base64,${btoa(this.typedSignature)}`;
            case 'draw': return this.drawnSignatureData;
            case 'upload': return this.uploadedSignature;
            default: return '';
        }
    }

    // --- UTILITY METHODS ---
    resetSignatureData() {
        this.selectedRequestId = null;
        this.documentTitle = '';
        this.selectedMethod = 'draw';
        this.typedSignature = '';
        this.drawnSignatureData = '';
        this.uploadedSignature = '';
        this.signerEmail = '';
        this.signerName = '';
        this.termsAccepted = false;
        this.canvas = null; // Important to re-initialize the canvas
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}