import { LightningElement } from 'lwc';

export default class ParentDocumentWorkspace extends LightningElement {

    showTemplateManager = true;
    showGenerator = false;
    showViewer = false;
    showSignature = false;
    showAiAdmin = false;
    showAiConfig = false;
    showApprovalConsole = false;

    // ================= BUTTON VARIANTS =================

    get templateManagerVariant() {
        return this.showTemplateManager ? "brand" : "neutral";
    }

    get generatorVariant() {
        return this.showGenerator ? "brand" : "neutral";
    }

    get viewerVariant() {
        return this.showViewer ? "brand" : "neutral";
    }

    get signatureVariant() {
        return this.showSignature ? "brand" : "neutral";
    }

    get aiAdminVariant() {
        return this.showAiAdmin ? "brand" : "neutral";
    }

    get aiConfigVariant() {
        return this.showAiConfig ? "brand" : "neutral";
    }

    get approvalConsoleVariant() {
        return this.showApprovalConsole ? "brand" : "neutral";
    }

    // ================= RESET METHOD =================

    hideAllSections() {
        this.showTemplateManager = false;
        this.showGenerator = false;
        this.showViewer = false;
        this.showSignature = false;
        this.showAiAdmin = false;
        this.showAiConfig = false;
        this.showApprovalConsole = false;
    }

    // ================= BUTTON ACTIONS =================

    showTemplateManagerSection() {
        this.hideAllSections();
        this.showTemplateManager = true;
    }

    showGeneratorSection() {
        this.hideAllSections();
        this.showGenerator = true;
    }

    showViewerSection() {
        this.hideAllSections();
        this.showViewer = true;
    }

    showSignatureSection() {
        this.hideAllSections();
        this.showSignature = true;
    }

    showAiAdminSection() {
        this.hideAllSections();
        this.showAiAdmin = true;
    }

    showAiConfigSection() {
        this.hideAllSections();
        this.showAiConfig = true;
    }

    showApprovalConsoleSection() {
        this.hideAllSections();
        this.showApprovalConsole = true;
    }
}