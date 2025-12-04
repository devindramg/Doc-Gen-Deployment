import { LightningElement, api, track } from 'lwc';

export default class TemplateEditor extends LightningElement {
    @track editableTemplate = {};
    _templateRecord;

    @api 
    get templateRecord() {
        return this._templateRecord;
    }
    set templateRecord(value) {
        this._templateRecord = value;
        // Create a deep copy for safe editing
        this.editableTemplate = JSON.parse(JSON.stringify(value));
    }

    get activeOptions() {
        return [{ label: 'Is Active', value: 'true' }];
    }

    get activeValue() {
        return this.editableTemplate.IsActive__c ? ['true'] : [];
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        
        if (field === 'IsActive__c') {
            this.editableTemplate.IsActive__c = event.detail.value.includes('true');
        } else if (field === 'Body__c') {
            // For rich text editor
            this.editableTemplate.Body__c = event.detail.value;
        } else {
            // For standard inputs
            this.editableTemplate[field] = event.target.value;
        }
    }

    handleSaveClick() {
        this.dispatchEvent(new CustomEvent('save', {
            detail: { template: this.editableTemplate }
        }));
    }

    handleCancelClick() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }
}