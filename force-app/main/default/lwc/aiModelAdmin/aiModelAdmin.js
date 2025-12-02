import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getModels from '@salesforce/apex/AIModelAdminController.getModels';
import setDefaultModel from '@salesforce/apex/AIModelAdminController.setDefaultModel';

// Define actions for the row actions menu Devindrappa
const ACTIONS = [   
    { label: 'Set as Default', name: 'set_default' }
];

// Define the columns for the datatable
const COLUMNS = [
    { label: 'Model Name', fieldName: 'label', wrapText: true },
    { label: 'Provider', fieldName: 'provider' },
    { label: 'Is Default?', fieldName: 'isDefault', type: 'boolean', cellAttributes: { iconName: { fieldName: 'defaultIcon' }, iconPosition: 'left', class: 'slds-text-align_center' } },
    { label: 'Status', fieldName: 'status', cellAttributes: { class: { fieldName: 'statusClass' } } },
    { type: 'action', typeAttributes: { rowActions: ACTIONS } }
];

export default class AiModelAdmin extends LightningElement {
    columns = COLUMNS;
    @track tableData = []; // Use a dedicated tracked property for the table
    wiredModelsResult; // To hold the provisioned result for refreshing
    error; // To hold any error information
    isLoading = true; // Start in a loading state

    @wire(getModels)
    wiredModels(result) {
        this.wiredModelsResult = result; // Store the raw result for refreshApex
        console.log('Wired AI Models Result1212:', JSON.stringify(result)); 
        if (result.data) {
            // Process the data and assign it to our tracked property
            this.tableData = result.data.map(model => ({
                ...model,
                defaultIcon: model.isDefault ? 'utility:check' : '', // Show checkmark if default
                status: model.isActive ? 'Active' : 'Inactive',
                statusClass: model.isActive ? 'slds-text-color_success' : 'slds-text-color_error'
            }));
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.tableData = []; // Clear data on error
            console.error('Error loading AI models:', JSON.stringify(result.error));
        }
        this.isLoading = false; // Stop loading once data or error is received
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'set_default') {
            if (row.isDefault) {
                this.showToast('Info', 'This model is already the default.', 'info');
                return;
            }

            this.isLoading = true;
            try {
                await setDefaultModel({ developerName: row.developerName });
                this.showToast('Success', `${row.label} is now the default AI model.`, 'success');
                return refreshApex(this.wiredModelsResult); // Refresh data from the server
            } catch (error) {
                this.showToast('Error', error.body?.message || 'Failed to set default model.', 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}