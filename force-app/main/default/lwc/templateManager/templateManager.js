import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDocumentTemplates from '@salesforce/apex/DocumentGenerationController.getDocumentTemplates';
import saveTemplate from '@salesforce/apex/DocumentGenerationController.saveTemplate';

// --- UPDATE THE COLUMNS DEFINITION HERE ---
const COLS = [
    { label: 'Template Name', fieldName: 'Name', type: 'text', sortable: true },
    { label: 'Region', fieldName: 'Region1__c', type: 'text', sortable: true },
    { label: 'Role', fieldName: 'Role__c', type: 'text', sortable: true },
    { label: 'Contract Type', fieldName: 'Contract_Type__c', type: 'text', sortable: true },
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
       // This now creates a new template object with the full, rich default body
    this.selectedTemplate = {
        sobjectType: 'DocumentTemplate__c',
        Name: 'New Employment Agreement',
        Body__c: `
        <div style="font-family: Arial, Helvetica, sans-serif; max-width: 900px; margin: 0 auto; padding: 40px; border: 2px solid #000;">
            
            <!-- Header -->
            <div style="text-align: center;">
                <h1 style="margin-bottom: 5px;">EMPLOYMENT AGREEMENT</h1>
                <p style="font-size: 14px;"><strong>Document Version:</strong> {{template.Version__c}}</p>
            </div>

            <hr style="margin: 25px 0;"/>

            <!-- Employee Details -->
            <table style="width: 100%; border-collapse: collapse; margin-bottom: 30px;">
                <tr>
                    <td style="padding: 8px; width: 30%;"><strong>Name:</strong></td>
                    <td style="padding: 8px;">{{template.Name}}</td>
                </tr>
                <tr>
                    <td style="padding: 8px;"><strong>Region:</strong></td>
                    <td style="padding: 8px;">{{template.Region1__c}}</td>
                </tr>
                <tr>
                    <td style="padding: 8px;"><strong>Role:</strong></td>
                    <td style="padding: 8px;">{{template.Role__c}}</td>
                </tr>
                <tr>
                    <td style="padding: 8px;"><strong>Contract Type:</strong></td>
                    <td style="padding: 8px;">{{template.Contract_Type__c}}</td>
                </tr>
            </table>

            <!-- Agreement Intro -->
            <p style="font-size: 15px; line-height: 1.6;">
                This Employment Agreement ("Agreement") is entered into between 
                <strong>{{template.Name}}</strong> ("Employee") and the Company ("Employer"). 
                This Agreement defines the terms and conditions of employment.
            </p>

            <hr style="margin: 25px 0;"/>

            <!-- AI Clause Section -->
            <h3 style="margin-bottom: 10px;">Terms & Conditions</h3>
            <div style="font-size: 15px; line-height: 1.7; padding: 15px; border: 1px solid #999; background-color: #f9f9f9;">
                {{aiClause}}
            </div>

            <hr style="margin: 30px 0;"/>

            <!-- Signature Section -->
            <table style="width: 100%; margin-top: 40px;">
                <tr>
                    <td style="width: 45%;">
                        <p><strong>Signed By (Employee)</strong></p>
                        <p style="margin-top: 40px;">___________________________</p>
                        <p>Name: {{template.Name}}</p>
                        <p>Date: ___________________</p>
                    </td>

                    <td style="width: 10%;"></td>

                    <td style="width: 45%;">
                        <p><strong>Company Representative</strong></p>
                        <p style="margin-top: 40px;">___________________________</p>
                        <p>Name: ___________________</p>
                        <p>Date: ___________________</p>
                    </td>
                </tr>
            </table>

            <div style="margin-top: 40px;">
                <p><strong>Receiving Party</strong></p>
                <p style="margin-top: 30px;">______________________________</p>
            </div>

        </div>
    `,
        Version__c: 1,
        IsActive__c: false,
        Region1__c: '',         // Initialize with blank values
        Role__c: '',
        Contract_Type__c: ''
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