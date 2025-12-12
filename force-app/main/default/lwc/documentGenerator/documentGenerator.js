import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
// Core Document Generation Methods
import getActiveTemplatesForSelection from '@salesforce/apex/DocumentGenerationController.getActiveTemplatesForSelection';
import previewDocument from '@salesforce/apex/DocumentGenerationController.previewDocument';
import generateFinalDocument from '@salesforce/apex/DocumentGenerationController.generateFinalDocument';
// AI-Related Apex Methods
import getAvailableAIModels from '@salesforce/apex/AIModelManager.getAvailableAIModels';
import generateClauseWithAI from '@salesforce/apex/DocumentGenerationController.generateClauseWithAI';

export default class DocumentGenerator extends NavigationMixin(LightningElement) {
    @track currentStep = 'step1';
    @track isLoading = false;
    @track selectedTemplateId = '';
    @track jsonData = `{ "contact": { "Name": "Jane Doe", "Title": "Senior Software Engineer", "Email": "jane.doe@example.com", "IsUSCitizen": true, "Address": { "Street": "123 Innovation Drive", "City": "San Francisco", "State": "CA", "PostalCode": "94105", "Country": "USA" } }, "company": { "Name": "Tech Innovations Inc.", "Address": { "Street": "456 Market Street", "City": "San Francisco", "State": "CA", "PostalCode": "94105", "Country": "USA" }, "Website": "www.techinnovations.com" }, "agreement": { "DocumentType": "Employment Agreement", "Region": "US", "Role": "Employee", "EffectiveDate": "2025-12-04", "Version": "1.0", "ConfidentialityPeriod": "5 years" }}`;
    @track templateOptions = [];
    @track previewHtml = '';
    @track validationErrors = [];

    // AI Model properties
    @track aiModelOptions = [];
    @track selectedAIModelId = '';
    @track aiPrompt = 'Suggest a standard confidentiality clause.';
    @track generatedClause = '';
    @track isGeneratingClause = false;

    // NEW: AI Feature Toggle
    @track aiFeaturesEnabled = false; // Default to off

    // State for success screen
    @track generationComplete = false;
    @track newRecordId = '';
    @track newContentDocumentId = '';

    get isStep1() { return this.currentStep === 'step1'; }
    get isStep2() { return this.currentStep === 'step2'; }
    get hasValidationErrors() { return this.validationErrors.length > 0; }

    // Wire to get document templates
    @wire(getActiveTemplatesForSelection)
    wiredTemplates({ error, data }) {
        if (data) {
            this.templateOptions = data.map(template => ({
                label: template.Name,
                value: template.Id
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load templates.', 'error');
        }
    }

    // Wire to get available AI models
    @wire(getAvailableAIModels)
    wiredAIModels({ error, data }) {
        if (data) {
            this.aiModelOptions = data.map(model => ({
                label: `${model.modelName} (${model.provider})`,
                value: model.modelIdentifier
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load AI models.', 'error');
        }
    }

    // --- Event Handlers for Step 1 ---
    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
    }

    handleJsonChange(event) {
        this.jsonData = event.target.value;
    }

    // NEW: Handler for the AI feature toggle
    handleAIToggle(event) {
        this.aiFeaturesEnabled = event.detail.checked;
        // If user turns AI off, clear any previously generated clause
        if (!this.aiFeaturesEnabled) {
            this.generatedClause = '';
        }
    }

    handleAIModelChange(event) {
        this.selectedAIModelId = event.detail.value;
    }

    handleAIPromptChange(event) {
        this.aiPrompt = event.target.value;
    }

    async handleSuggestClauseClick() {
        if (!this.selectedAIModelId) {
            this.showToast('Warning', 'Please select an AI model first.', 'warning');
            return;
        }
        this.isGeneratingClause = true;
        this.generatedClause = '';
        try {
            const result = await generateClauseWithAI({
                modelId: this.selectedAIModelId,
                prompt: this.aiPrompt,
                jsonContext: this.jsonData
            });
            this.generatedClause = result;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to generate AI clause.', 'error');
        } finally {
            this.isGeneratingClause = false;
        }
    }

    // --- Navigation and Core Logic ---
    handleBackClick() {
        this.currentStep = 'step1';
        this.previewHtml = '';
        this.validationErrors = [];
    }

    async handlePreviewClick() {
        if (!this.selectedTemplateId || !this.jsonData) {
            this.showToast('Warning', 'Please select a template and provide JSON data.', 'warning');
            return;
        }
        this.isLoading = true;
        try {
            // Pass the generated clause only if AI features are enabled
            const clauseToSend = this.aiFeaturesEnabled ? this.generatedClause : '';
            const result = await previewDocument({
                templateId: this.selectedTemplateId,
                jsonData: this.jsonData,
                aiClauseText: clauseToSend
            });
            if (result.success) {
                console.log('Preview Result:', result);
                this.previewHtml = result.renderedContent;
                this.validationErrors = [];
                this.currentStep = 'step2';
            } else {
                this.validationErrors = result.validationErrors;
                this.previewHtml = '';
                this.currentStep = 'step2';
            }
        } catch (error) {
            this.validationErrors = [error.body?.message || 'An unknown server error occurred.'];
            this.previewHtml = '';
        } finally {
            this.isLoading = false;
        }
    }

    async handleGenerateClick() {
        this.isLoading = true;
        try {
            // Pass the generated clause only if AI features are enabled
            const clauseToSend = this.aiFeaturesEnabled ? this.generatedClause : '';
            const result = await generateFinalDocument({
                templateId: this.selectedTemplateId,
                jsonData: this.jsonData,
                aiClauseText: clauseToSend,
                selectedAIModel: this.selectedAIModelId
            });
            if (result.success && result.recordId) {
                this.showToast('Success', 'Document generated successfully!', 'success');
                this.generationComplete = true;
                this.newRecordId = result.recordId;
                this.newContentDocumentId = result.contentDocumentId;
            } else {
                this.showToast('Error', result.errorMessage, 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'An unknown error occurred.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // --- Success Screen Handlers ---
    handleViewDocument() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                recordIds: this.newContentDocumentId
            }
        });
    }

    handleDownloadDocument() {
        const downloadUrl = `/sfc/servlet.shepherd/document/download/${this.newContentDocumentId}`;
        window.open(downloadUrl, '_blank');
    }

    handleGenerateNew() {
        this.resetComponent();
        this.showToast('Ready', 'You can now generate a new document.', 'success');
    }

    // --- Utility Methods ---
    resetComponent() {
        this.currentStep = 'step1';
        this.isLoading = false;
        this.selectedTemplateId = '';
        this.previewHtml = '';
        this.validationErrors = [];
        this.generationComplete = false;
        this.newRecordId = '';
        this.newContentDocumentId = '';

        // Reset AI fields
        this.aiFeaturesEnabled = false; // Turn toggle off
        this.selectedAIModelId = '';
        this.generatedClause = '';
        this.aiPrompt = 'Suggest a standard confidentiality clause.';
    }

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