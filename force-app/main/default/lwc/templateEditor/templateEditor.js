import { LightningElement, api, track, wire } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';

// Import the object and the new fields
import DOCUMENT_TEMPLATE_OBJECT from '@salesforce/schema/DocumentTemplate__c';
import REGION_FIELD from '@salesforce/schema/DocumentTemplate__c.Region1__c';
import ROLE_FIELD from '@salesforce/schema/DocumentTemplate__c.Role__c';
import CONTRACT_TYPE_FIELD from '@salesforce/schema/DocumentTemplate__c.Contract_Type__c';

export default class TemplateEditor extends LightningElement {
    @track editableTemplate = {};
    _templateRecord;

    @track regionOptions;
    @track roleOptions;
    @track contractTypeOptions;

    @wire(getObjectInfo, { objectApiName: DOCUMENT_TEMPLATE_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: REGION_FIELD })
    wiredRegionPicklist({ error, data }) {
        if (data) {
            this.regionOptions = data.values;
        } else if (error) {
            console.error('Error loading Region picklist', JSON.stringify(error));
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: ROLE_FIELD })
    wiredRolePicklist({ error, data }) {
        if (data) {
            this.roleOptions = data.values;
        } else if (error) {
            console.error('Error loading Role picklist', JSON.stringify(error));
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: CONTRACT_TYPE_FIELD })
    wiredContractTypePicklist({ error, data }) {
        if (data) {
            this.contractTypeOptions = data.values;
        } else if (error) {
            console.error('Error loading Contract Type picklist', JSON.stringify(error));
        }
    }

    @api
    get templateRecord() {
        return this._templateRecord;
    }
    set templateRecord(value) {
        this._templateRecord = value;
        // Create a deep copy for safe editing and to handle null on new records
        this.editableTemplate = JSON.parse(JSON.stringify(value || {}));

        // Set defaults for a brand new template
        // Set defaults for a brand new template
        if (!this.editableTemplate.Body__c) {
            this.editableTemplate.Body__c = '<h1>Employment Agreement</h1><p><strong>Region:</strong> {{template.Region1__c}}<br/><strong>Role:</strong> {{template.Role__c}}<br/><strong>Contract Type:</strong> {{template.Contract_Type__c}}</p><hr/><p>This agreement is between <strong>{{contact.Name}}</strong> and our company.</p><p>{{aiClause}}</p><hr/><p><em>Document Version: {{template.Version__c}}</em></p>';
        }
        if (this.editableTemplate.Version__c === undefined) {
            this.editableTemplate.Version__c = 1;
        }
        if (this.editableTemplate.IsActive__c === undefined) {
            this.editableTemplate.IsActive__c = false;
        }
    }

    // Generic handler for standard inputs and comboboxes
    handleChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail.value;
        this.editableTemplate[field] = value;
    }

    // Specific handler for the rich text editor
    handleBodyChange(event) {
        this.editableTemplate.Body__c = event.target.value;
    }

    // Specific handler for the 'Is Active' toggle
    handleIsActiveChange(event) {
        this.editableTemplate.IsActive__c = event.target.checked;
    }

    handleSaveClick() {
        // Now it correctly dispatches the complete, updated object
        this.dispatchEvent(new CustomEvent('save', { detail: { template: this.editableTemplate } }));
    }

    handleCancelClick() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }
}