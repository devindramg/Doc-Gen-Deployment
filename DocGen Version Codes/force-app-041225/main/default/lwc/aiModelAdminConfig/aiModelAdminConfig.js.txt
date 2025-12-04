import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getModels from '@salesforce/apex/AIModelAdminController.getModels';
import saveModel from '@salesforce/apex/AIModelAdminController.saveModel';
import updateModelStatus from '@salesforce/apex/AIModelAdminController.updateModelStatus';
import deleteModel from '@salesforce/apex/AIModelAdminController.deleteModel';
import testModelConnection from '@salesforce/apex/AIModelAdminController.testModelConnection';

const TOAST_VARIANTS = { SUCCESS: 'success', WARNING: 'warning', ERROR: 'error', INFO: 'info' };
const TEST_MESSAGES = { TESTING: 'Testing connection, please wait...', SUCCESS_PREFIX: 'SUCCESS:', ERROR_PREFIX: 'ERROR:' };

// **CORRECTION**: Updated fieldName to match the clean wrapper properties from Apex
const COLUMNS = [
    { label: 'Model Name', fieldName: 'Name', type: 'text', sortable: true },
    { label: 'Provider', fieldName: 'Model_Provider', type: 'text', sortable: true },
    { label: 'Status', fieldName: 'statusLabel', type: 'text', sortable: true, cellAttributes: { class: { fieldName: 'statusClass' }, iconName: { fieldName: 'statusIcon' }, iconPosition: 'left' } },
    { label: 'Context Window', fieldName: 'Context_Window_Size', type: 'number', sortable: true },
    { label: 'Cost per Token', fieldName: 'Cost_Per_Token', type: 'currency', typeAttributes: { currencyCode: 'USD', minimumFractionDigits: '6' } },
    { type: 'action', typeAttributes: { rowActions: [
        { label: 'Toggle Active/Inactive', name: 'toggle' },
        { label: 'Test', name: 'test' },
        { label: 'Edit', name: 'edit' },
        { label: 'Delete', name: 'delete' }
    ]}}
];

const DEFAULT_TEST_PROMPT = 'Hello, please respond with a simple greeting to confirm connectivity.';

export default class AiModelAdminConfig extends LightningElement {
    // --- State management ---
    @track aiModels = [];
    @track selectedTestModel = '';
    @track testPrompt = DEFAULT_TEST_PROMPT;
    @track testResult = '';
    @track testMetrics = null;
    @track testHistory = [];
    @track showTestSection = false;
    @track showTestHistory = false;
    @track showHelp = false;
    @track isTestRunning = false;
    @track sortedBy = 'Name';
    @track sortedDirection = 'asc';
    @track lastUpdated = '';

    // --- Modal State ---
    @track showModal = false;
    @track modalTitle = '';
    @track currentModel = {};

    // --- Configuration ---
    columns = COLUMNS;
    wiredModelsResult;

    // --- Component lifecycle ---
    connectedCallback() {
        this.updateLastUpdatedTime();
    }

    // --- Wire method for loading AI models ---
    @wire(getModels)
    wiredModels(result) {
        this.wiredModelsResult = result;
        if (result.data) {
            this.processModelData(result.data);
            this.updateLastUpdatedTime();
        } else if (result.error) {
            this.handleError('Failed to load AI models', result.error);
        }
    }

    // --- Data processing and computed properties ---
    processModelData(data) {
        // **CORRECTION**: Use the clean 'Is_Active' property from the wrapper
        this.aiModels = data.map(model => ({
            ...model,
            statusLabel: model.Is_Active ? 'Active' : 'Inactive',
            statusClass: model.Is_Active ? 'slds-text-color_success' : 'slds-text-color_error',
            statusIcon: model.Is_Active ? 'utility:success' : 'utility:error'
        }));
        this.showTestSection = this.aiModels.length > 0;
        this.showHelp = this.aiModels.length === 0;
    }

    // --- Getters for template binding ---
    get modelTestOptions() {
        // **CORRECTION**: Use clean property names from the wrapper
        return this.aiModels
            .filter(model => model.Is_Active)
            .map(model => ({
                label: `${model.Name} (${model.Model_Provider})`,
                value: model.DeveloperName // Use clean DeveloperName for testing
            }));
    }

    get testButtonDisabled() {
        return !this.selectedTestModel || this.isTestRunning || !this.testPrompt?.trim();
    }

    get testResultClass() {
        const baseClass = 'slds-box slds-box_small slds-m-top_medium ';
        if (this.testResult.includes(TEST_MESSAGES.SUCCESS_PREFIX)) {
            return baseClass + 'slds-theme_success';
        }
        if (this.testResult.includes(TEST_MESSAGES.ERROR_PREFIX)) {
            return baseClass + 'slds-theme_error';
        }
        return baseClass + 'slds-theme_info';
    }

    get testResultIcon() {
        if (this.testResult.includes(TEST_MESSAGES.SUCCESS_PREFIX)) { return 'utility:success'; }
        if (this.testResult.includes(TEST_MESSAGES.ERROR_PREFIX)) { return 'utility:error'; }
        return 'utility:info';
    }

    get testResultTitle() {
        if (this.testResult.includes(TEST_MESSAGES.SUCCESS_PREFIX)) { return 'Connection Successful'; }
        if (this.testResult.includes(TEST_MESSAGES.ERROR_PREFIX)) { return 'Connection Failed'; }
        return 'Test Information';
    }

    // --- Modal Handlers ---
    handleAddModel() {
        this.modalTitle = 'Add New AI Model';
        this.currentModel = { Is_Active: true }; // Default new models to active
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
        this.currentModel = {};
    }

    handleFieldChange(event) {
        // This now works directly with clean property names from data-id
        const field = event.target.dataset.id;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.currentModel = { ...this.currentModel, [field]: value };
    }

    async handleSave() {
        try {
            // The currentModel object now has clean keys, matching the Apex DTO
            await saveModel({ jsonModel: JSON.stringify(this.currentModel) });
            this.showToast('Success', 'Model configuration saved successfully.', TOAST_VARIANTS.SUCCESS);
            this.handleCloseModal();
            return refreshApex(this.wiredModelsResult);
        } catch (error) {
            this.handleError('Save Failed', error);
        }
    }

    // --- Event handlers ---
    handleTestModelSelection(event) { this.selectedTestModel = event.detail.value; }
    handleTestPromptChange(event) { this.testPrompt = event.detail.value; }
    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
    }

    handleRefreshModels() {
        refreshApex(this.wiredModelsResult)
            .then(() => {
                this.showToast('Success', 'Models refreshed successfully', TOAST_VARIANTS.SUCCESS);
                this.updateLastUpdatedTime();
            })
            .catch(error => {
                this.handleError('Failed to refresh models', error);
            });
    }

    // --- Test connection functionality ---
    async handleTestConnection() {
        this.isTestRunning = true;
        this.testResult = TEST_MESSAGES.TESTING;
        try {
            const result = await testModelConnection({ modelId: this.selectedTestModel, testPrompt: this.testPrompt });
            this.testResult = result;
        } catch (error) {
            this.handleError('Connection test failed', error);
            this.testResult = `${TEST_MESSAGES.ERROR_PREFIX}: ${this.extractErrorMessage(error)}`;
        } finally {
            this.isTestRunning = false;
        }
    }

    // --- Row actions handler ---
    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case 'toggle':
                await this.toggleModelStatus(row);
                break;
            case 'test':
                // **CORRECTION**: Use clean DeveloperName
                this.selectedTestModel = row.DeveloperName;
                await this.handleTestConnection();
                break;
            case 'edit':
                this.modalTitle = `Edit ${row.Name}`;
                // The 'row' object already has clean properties, so this works perfectly
                this.currentModel = JSON.parse(JSON.stringify(row));
                this.showModal = true;
                break;
            case 'delete':
                // eslint-disable-next-line no-alert
                if (confirm(`Are you sure you want to delete "${row.Name}"? This action cannot be undone.`)) {
                    await this.deleteRecord(row.recordId);
                }
                break;
            default:
        }
    }

    // --- Model management DML methods ---
    async toggleModelStatus(model) {
        // **CORRECTION**: Use clean 'Is_Active' property
        const newStatus = !model.Is_Active;
        try {
            await updateModelStatus({ recordId: model.recordId, isActive: newStatus });
            this.showToast('Success', `Model ${newStatus ? 'activated' : 'deactivated'} successfully`, TOAST_VARIANTS.SUCCESS);
            await refreshApex(this.wiredModelsResult);
        } catch (error) {
            this.handleError('Failed to update model status', error);
        }
    }

    async deleteRecord(recordId) {
        try {
            await deleteModel({ recordId: recordId });
            this.showToast('Success', 'Model deleted successfully.', TOAST_VARIANTS.SUCCESS);
            await refreshApex(this.wiredModelsResult);
        } catch(error) {
            this.handleError('Failed to delete model', error);
        }
    }

    // --- Utility methods ---
    updateLastUpdatedTime() { this.lastUpdated = new Date().toLocaleString(); }
    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'An unknown error occurred';
    }
    handleError(title, error) {
        console.error(title, JSON.stringify(error));
        const message = this.extractErrorMessage(error);
        this.showToast(title, message, TOAST_VARIANTS.ERROR);
    }
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: variant === TOAST_VARIANTS.ERROR ? 'sticky' : 'dismissable' }));
    }
}