import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDocumentTemplates from '@salesforce/apex/DocumentGenerationController.getDocumentTemplates';
import saveTemplate from '@salesforce/apex/DocumentGenerationController.saveTemplate';

const COLS = [
    { label: 'Template Name', fieldName: 'Name', type: 'text', sortable: true },
    { label: 'Version', fieldName: 'Version__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Active', fieldName: 'IsActive__c', type: 'boolean' }
];

export default class TemplateManager extends LightningElement {
    @track templates = [];
    @track selectedTemplate = {};
    @track isEditing = false;
    @track isLoading = true;
    columns = COLS;
    wiredTemplatesResult;

    @wire(getDocumentTemplates)
    wiredTemplates(result) {
        this.isLoading = false;
        this.wiredTemplatesResult = result;
        if (result.data) {
            this.templates = result.data;
        } else if (result.error) {
            this.showToast('Error', 'Failed to load templates.', 'error');
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length > 0) {
            // --- FIX --- Cloning the object to prevent unintended mutations
            this.selectedTemplate = { ...selectedRows[0] };
            this.isEditing = true;
        }
    }

    handleNew() {
        this.selectedTemplate = {
            sobjectType: 'DocumentTemplate__c',
            Name: 'New Employment Agreement',
            Body__c: '<h1>Employment Agreement</h1><p>This agreement is between {{contact.Name}} and our company.</p>',
            Version__c: 1,
            IsActive__c: false
        };
        this.isEditing = true;
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = [];
        }
    }

    async handleSave(event) {
        this.isLoading = true;
        try {
            await saveTemplate({ templateRecord: event.detail.template });
            this.showToast('Success', 'Template saved successfully.', 'success');
            this.isEditing = false;
            await refreshApex(this.wiredTemplatesResult);
        } catch (error) {
            this.showToast('Error', 'Failed to save template: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.isEditing = false;
        this.selectedTemplate = {};
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = [];
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}