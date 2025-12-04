import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPendingApprovals from '@salesforce/apex/ApprovalManagerController.getPendingApprovals';
import submitApproval from '@salesforce/apex/ApprovalManagerController.submitApproval';

const COLS = [
    { label: 'Document', fieldName: 'DocumentTitle', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Received Date', fieldName: 'DocumentCreatedDate', type: 'date' },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Review', name: 'review' }] },
    },
];

export default class ApprovalConsole extends LightningElement {
    @track columns = COLS;
    @track showModal = false;
    @track comments = '';
    @track selectedApprovalId;
    
    wiredApprovalsResult;

    @wire(getPendingApprovals)
    wiredApprovals(result) {
        this.wiredApprovalsResult = result;
        if (result.error) {
            this.showToast('Error', 'Could not load approvals.', 'error');
        }
    }
    
    get approvals() {
        if (this.wiredApprovalsResult && this.wiredApprovalsResult.data) {
            return {
                ...this.wiredApprovalsResult,
                data: this.wiredApprovalsResult.data.map(row => ({
                    ...row,
                    DocumentTitle: row.Document__r.Title,
                    DocumentCreatedDate: row.Document__r.CreatedDate
                }))
            };
        }
        return this.wiredApprovalsResult;
    }

    handleRowAction(event) {
        this.selectedApprovalId = event.detail.row.Id;
        this.showModal = true;
    }

    handleCommentsChange(event) {
        this.comments = event.target.value;
    }

    closeModal() {
        this.showModal = false;
        this.comments = '';
        this.selectedApprovalId = null;
    }

    handleApprove() {
        this.submit('Approved');
    }

    handleReject() {
        this.submit('Rejected');
    }

    async submit(status) {
        try {
            await submitApproval({
                approvalId: this.selectedApprovalId,
                status: status,
                comments: this.comments
            });
            this.showToast('Success', `Approval submitted as ${status}`, 'success');
            this.closeModal();
            return refreshApex(this.wiredApprovalsResult);
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}